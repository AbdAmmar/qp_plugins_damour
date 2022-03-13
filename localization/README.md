Installation on qp2 
Go to the qp2 directory  
``` 
./bin/qpsh  
cd plugins  
git clone -b dev https://github.com/Ydrnan/qp_plugins_damour  
qp_plugins install localization
cd qp_plugins_damour/trust_region
./TANGLE_org_mode.sh  
ninja
cd ../localization
./TANGLE_org_mode.sh  
ninja  
``` 
Please, use the ifort compiler  
  
Some parameters can be changed with qp edit in the Orbital_optimization section 
 
If you modify the .org files, don't forget to do:  
``` 
./TANGLE_org_mode.sh  
ninja  
```  

The documentation can be read using:  
Ctrl-C Ctrl-e l p  
after opening the filename.org in emacs. It will produce a  
filename.pdf.  
(Not available for all the files)  
!!! Warning: the documentation can contain some errors !!! 

# Orbital localisation
To localize the MOs:  
```
qp run localization  
```
After that the ezfio directory contains the localized MOs  
 
But the mo_class must be defined before, run 
```
qp set_mo_class -q
```
for more information or  
```
qp set_mo_class -c [] -a [] -v [] -i [] -d [] 
```
to set the mo classes. We don't care about the name of the   
mo classes. The algorithm just localizes all the MOs of  
a given class between them, for all the classes, except the deleted MOs.  

If you just on kind of mo class to localize all the MOs between them  
you have to put:
```
qp set localization security_mo_class false
```

Before the localization, a kick is done for each mo class  
(except the deleted ones) to break the MOs. This is done by   
doing a given rotation between the MOs.
This feature can be removed by setting:
```
qp set localization kick_in_mos false
```
and the default angle for the rotation can be changed with:
```
qp set localization angle_pre_rot 1e-3 # or something else
```

After the localization, the MOs of each class (except the deleted ones)  
can be sorted between them using the diagonal elements of  
the fock matrix with:
```
qp set localization sort_mos_by_e true # Not working
```

## Foster-Boys & Pipek-Mezey
Foster-Boys:  
``` 
qp set localization localization_method boys 
``` 
 
Pipek-Mezey:  
``` 
qp set localization localization_method pipek 
``` 

# Break the spatial symmetry of the MOs
To break the spatial symmetry of the MOs:   
```
qp run break_spatial_sym
```
The default angle for the rotations is too big for this kind of
application, a value between 1e-3 and 1e-6 should break the spatial
symmetry with just a small change in the energy:
```
qp set localization angle_pre_rot 1e-3
``` 

# Further improvements: 
- Cleaner repo 
- Correction of the errors in the documentations 
- option with/without trust region 
