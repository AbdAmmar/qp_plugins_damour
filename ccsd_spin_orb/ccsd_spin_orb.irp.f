! Prog

program ccsd

  implicit none

  BEGIN_DOC
  ! CCSD in spin orbitals
  END_DOC

  read_wf = .True.

  call run_ccsd_spin_orb_sub
  
end
