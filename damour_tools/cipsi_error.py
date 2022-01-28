#!/usr/bin/env python

# Old format:
# Ndet  rPT2_0 PT2_0 E_0 Ndet rPT2_1 PT2_1 E_1 ...

# New format:
# Ndet E_0 PT2_0 Error_PT2_0 rPT2_0 Error_rPT2_0 E_1 ...

def student(p,df):
    import scipy
    from scipy.stats import t
    return t.ppf(p, df)


def chi2cdf(x,k):
    import scipy
    import scipy.stats
    return scipy.stats.chi2.cdf(x,k)


def jarque_bera(data):

    n    = max(len(data), 2)
    norm = 1./ sum( [ w for (_,w) in data ] )

    mu     =   sum( [ w* x        for (x,w) in data ] ) * norm
    sigma2 =   sum( [ w*(x-mu)**2 for (x,w) in data ] ) * norm
    S      = ( sum( [ w*(x-mu)**3 for (x,w) in data ] ) * norm ) / sigma2**(3./2.)
    K      = ( sum( [ w*(x-mu)**4 for (x,w) in data ] ) * norm ) / sigma2**2

    # Value of the Jarque-Bera test
    JB = n/6. * (S**2 + 1./4. * (K-3.)**2)

    # Probability that the data comes from a Gaussian distribution
    p = 1. - chi2cdf(JB,2)

    return JB, mu, sqrt(sigma2/(n-1)), p



to_eV = 27.2107362681
import sys, os
import scipy
import scipy.stats
from math import sqrt, gamma, exp


def read_data(filename,state):
  """ Read energies and PT2 from input file """
  with open(filename,'r') as f:
      firstline = f.readline() # just to jump the comments one the first line
      lines = f.readlines()

  gs = []
  es = []

  for line in lines:
      l = line.split()
      #pt2_0 = float(l[2])
      #e_0   = float(l[3])
      #pt2_1 = float(l[2+4*state])
      #e_1   = float(l[3+4*state])
      pt2_0 = float(l[2])
      e_0   = float(l[1])
      pt2_1 = float(l[2+5*state])
      e_1   = float(l[1+5*state])
      gs.append( (e_0, pt2_0) )
      es.append( (e_1, pt2_1) )
      print(e_0, pt2_0, e_1, pt2_1)

  def f(p_1, p0, p1):
      e, pt2 = p0
      y0, x0 = p_1
      y1, x1 = p1
      try:
        alpha = (y1-y0)/(x0-x1)
      except ZeroDivisionError:
        alpha = 1.
      return [e, pt2, alpha]

  for l in (gs, es):
      p_1, p0, p1 = l[0], l[0], l[1]
      l[0] = f(p_1, p0, p1)

      for i in range(1,len(l)-1):
          p_1 = (l[i-1][0], l[i-1][1])
          p0  = l[i]
          p1  = l[i+1]
          l[i] = f(p_1, p0, p1)

      i = len(l)-1
      p_1 = (l[i-1][0], l[i-1][1])
      p0  = l[i]
      p1  = l[-1]
      l[i] = f(p_1, p0, p1)

  return [ x+y for x,y in zip(gs,es) ]


def compute(data):

    d = []
    for e0, p0, a0, e1, p1, a1 in data:
        x   = (e1+p1)-(e0+p0)
        w   = 1./sqrt(p0**2 + p1**2)
        bias = (a1-1.)*p1 - (a0-1.)*p0
        d.append( (x,w,bias) )

    x = []
    target = (scipy.stats.norm.cdf(1.)-0.5)*2   # = 0.6827

    print("| %2s | %8s | %8s | %8s | %8s | %8s |"%( "N", "DE", "+/-", "bias", "P(G)", "J"))
    print("|----+----------+----------+----------+----------+----------|")
    xmax = (0.,0.,0.,0.,0.,0,0.)
    for i in range(len(data)-1):
        jb, mu, sigma, p = jarque_bera( [ (x,w) for (x,w,bias) in d[i:] ] )
        bias = sum ( [ w * e for (_,w,e) in d[i:] ] ) / sum ( [ w for (_,w,_) in d[i:] ] )
        mu = (mu+0.5*bias) * to_eV
        sigma = sigma * to_eV
        bias = bias * to_eV
        n = len(data[i:])
        if p!=0.:
            beta = student(0.5*(1.+target/p) ,n)
        else:
            continue
        err = sigma * beta + 0.5*abs(bias)
        print("| %2d | %8.3f | %8.3f | %8.3f | %8.3f | %8.3f |"%( n, mu, err, bias, p, jb))
        if n < 3 :
            continue
        y = (err, p, mu, err, jb,n,bias)
        if p > xmax[1]: xmax = y
        if p < 0.8:
            continue
        x.append(y)

    x = sorted(x)

    print("|----+----------+----------+----------+----------+----------|")
    if x != []:
      xmax = x[0]
    _, p, mu, err, jb, n, bias = xmax
    beta = student(0.5*(1.+target/p),n)
    print("| %2d | %8.3f | %8.3f | %8.3f | %8.3f | %8.3f |\n"%(n, mu, err, bias, p, jb))

    return mu, err, bias, p

filename = sys.argv[1]
print(filename)
if len(sys.argv) > 2:
    state = int(sys.argv[2])
else:
    state = 1
data = read_data(filename,state)
mu, err, bias, _ = compute(data)
print(" %s: %8.3f +/- %5.3f eV\n"%(filename, mu, err))

import numpy as np
A = np.array( [ [ data[-1][1], 1. ],
                [ data[-2][1], 1. ] ] )
B = np.array( [ [ data[-1][0] ],
                [ data[-2][0] ] ] )
E0 = np.linalg.solve(A,B)[1]
A = np.array( [ [ data[-1][4], 1. ],
                [ data[-2][4], 1. ] ] )
B = np.array( [ [ data[-1][3] ],
                [ data[-2][3] ] ] )
E1 = np.linalg.solve(A,B)[1]
average_2 = (E1-E0)*to_eV

A = np.array( [ [ data[-1][1], 1. ],
                [ data[-2][1], 1. ],
                [ data[-3][1], 1. ] ] )
B = np.array( [ [ data[-1][0] ],
                [ data[-2][0] ],
                [ data[-3][0] ] ] )
E0 = np.linalg.lstsq(A,B,rcond=None)[0][1]
A = np.array( [ [ data[-1][4], 1. ],
                [ data[-2][4], 1. ],
                [ data[-3][4], 1. ] ] )
B = np.array( [ [ data[-1][3] ],
                [ data[-2][3] ],
                [ data[-3][3] ] ] )
E1 = np.linalg.lstsq(A,B,rcond=None)[0][1]
average_3 = (E1-E0)*to_eV

exc = ((data[-1][3] + data[-1][4]) - (data[-1][0] + data[-1][1])) * to_eV
error_2 = abs(average_2 - average_3)
error_3 = abs(average_3 - exc)
print(" 2-3 points: %.3f +/- %.3f "% (average_3, error_2))
print(" largest wf: %.3f +/- %.3f  "%(average_3, error_3))


