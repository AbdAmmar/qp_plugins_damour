#!/bin/python3
import copy
import sys

# Doc
# After a cispi calculation
# Execute:
#
# python3 extract_E_cipsi.py your_file.fci.out
#
# To create a file your_file.fci.out.dat with:
# Ndet  E_1  PT2  Error_PT2  rPT2 Error_rPT2 E_2 ...


#in
fname = sys.argv[1]
print(fname)

# out
out_file = fname + ".dat"

def f_search_str(search_str,fname):

    # init
    res = []
    load_file = open(fname,"r")
    read_file = load_file.readlines()

    # Research of the lines
    for line in read_file:
        if line.startswith(search_str):
            res.append(line)
    load_file.close()

    for i in range(len(res)):
        # transformation lines to lists
        res[i] = res[i].split()

        # deletion of the spaces
        for j in range(len(res[i])):
            res[i][j] = res[i][j].strip()

        # temporary list to delete the points/signs
        tmp_res = copy.deepcopy(res[i]) # real copy...
        for j in range(len(tmp_res)):
            tmp_res[j] = tmp_res[j].replace('.','')
            tmp_res[j] = tmp_res[j].replace('-','')
       
        # deletion of the character at the beginning
        j = 0
        while (not(tmp_res[j].isdigit())):
            del res[i][0] # if we delete the 1st, the 2nd becomes the 1st
            j = j + 1

    return res

# call the function to search the string
Ndet = f_search_str("Summary",fname)
E    = f_search_str("# E ",fname)
PT2  = f_search_str("# PT2",fname)
rPT2 = f_search_str("# rPT2",fname)

# write the output
f = open(out_file,"w")
# first line
f.write('{:14s}'.format("    Ndet"))
for i in range(len(E[0])):
    f.write('{:3s}'.format(" E_"))
    f.write('{:12s}'.format(str(i)))
    f.write('{:12s}'.format('PT2'))
    f.write('{:12s}'.format('Error_PT2'))
    f.write('{:12s}'.format('rPT2'))
    f.write('{:12s}'.format('Error_rPT2'))
f.write("\n")
# data
for i in range(len(Ndet)):
    f.write('{:10d}'.format(int(Ndet[i][0])))
    for j in range(len(E[0])):
        f.write('{:15f}'.format(float(E[i][j])))
        f.write('{:12f}'.format(float(PT2[i][2*j])))
        f.write('{:12f}'.format(float(PT2[i][2*j+1])))
        f.write('{:12f}'.format(float(rPT2[i][2*j])))
        f.write('{:12f}'.format(float(rPT2[i][2*j+1])))
    f.write("\n")
f.close()
