subroutine print_dipole_moment_xyz_v2

  implicit none

  BEGIN_DOC
  ! To print the dipole moment ||<Psi_i|µ|Psi_i>|| and its x,y,z components
  END_DOC

  integer :: istate
  double precision, allocatable :: d(:), d_x(:), d_y(:), d_z(:)

  allocate(d(N_states),d_x(N_states),d_y(N_states),d_z(N_states))
 
  do istate = 1, N_states 
    d_x(istate) = multi_s_x_dipole_moment(istate,istate)
    d_y(istate) = multi_s_y_dipole_moment(istate,istate)
    d_z(istate) = multi_s_z_dipole_moment(istate,istate)
    d(istate) = multi_s_dipole_moment(istate,istate)
  enddo

  print*,''
  print*,'# Dipoles:'
  print*,'=============================================='
  print*,' Dipole moments (au)'
  print*,' State      X           Y           Z         ||µ||' 

  do istate = 1, N_states 
    write(*,'(I5,4(F12.6))') (istate-1), d_x(istate), d_y(istate), d_z(istate), d(istate)
  enddo

  print*,''
  print*,' Dipole moments (D)'
  print*,' State      X           Y           Z         ||µ||' 

  do istate = 1, N_states 
    write(*,'(I5,4(F12.6))') (istate-1), d_x(istate)*au2D, d_y(istate)*au2D, d_z(istate)*au2D, d(istate)*au2D
  enddo

  print*,'=============================================='
  print*,''

  deallocate(d,d_x,d_y,d_z)

 end

subroutine print_transition_dipole_moment

  implicit none

  BEGIN_DOC
  ! To print the transition dipole moment ||<Psi_i|µ|Psi_j>|| and its components along x, y and z
  END_DOC

  integer          :: istate,jstate, n_states_print
  double precision :: f, d, d_x, d_y, d_z, osc_str

  print*,''
  print*,'# Transition dipoles:'
  print*,'=============================================='
  print*,' Transition dipole moments (au)'
  write(*,'(A89)') '   #  Transition       X           Y           Z         ||µ||     Dip. str.   Osc. str.'
 
  if (print_all_transitions) then
    n_states_print = N_states
  else
   n_states_print = 1
  endif

  do jstate = 1, n_states_print !N_states
    do istate = jstate + 1, N_states
      d_x = multi_s_x_dipole_moment(istate,jstate)
      d_y = multi_s_y_dipole_moment(istate,jstate)
      d_z = multi_s_z_dipole_moment(istate,jstate)
      osc_str = d_x**2 + d_y**2 + d_z**2
      d = multi_s_dipole_moment(istate,jstate)
      f = 2d0/3d0 * d * d * dabs(ci_energy(istate) - ci_energy(jstate))
      write(*,'(I4,I4,A4,I3,6(F12.6))') (istate-1), (jstate-1), '  ->', (istate-1), d_x, d_y, d_z, d, osc_str, f
    enddo
  enddo

  print*,''
  print*,' Transition dipole moments (D)'
  write(*,'(A89)') '   #  Transition       X           Y           Z         ||µ||     Dip. str.   Osc. str.'
  
  do jstate = 1, n_states_print !N_states
    do istate = jstate + 1, N_states
      d_x = multi_s_x_dipole_moment(istate,jstate) * au2D
      d_y = multi_s_y_dipole_moment(istate,jstate) * au2D
      d_z = multi_s_z_dipole_moment(istate,jstate) * au2D
      d = multi_s_dipole_moment(istate,jstate) 
      f = 2d0/3d0 * d * d * dabs(ci_energy(istate) - ci_energy(jstate))
      d = multi_s_dipole_moment(istate,jstate) * au2D
      write(*,'(I4,I4,A4,I3,6(F12.6))') (istate-1), (jstate-1), '  ->', (istate-1), d_x, d_y, d_z, d, d_x**2 + d_y**2 + d_z**2, f
    enddo
  enddo
  print*,'=============================================='
  print*,''

end

subroutine print_oscillator_strength

  implicit none

  BEGIN_DOC
  ! https://doi.org/10.1016/j.cplett.2004.03.126
  ! Oscillator strength in:
  ! - length gauge, f_l^ij = 2/3 (E_i - E_j) <Psi_i|r|Psi_j> <Psi_j|r|Psi_i>
  ! - velocity gauge, f_v^ij = 2/3 (E_i - E_j)^(-1) <Psi_i|v|Psi_j> <Psi_j|v|Psi_i>
  ! - mixed gauge, f_m^ij = -2i/3 <Psi_i|r|Psi_j> <Psi_j|v|Psi_i> 
  END_DOC
  
  integer :: istate,jstate,k, n_states_print
  double precision :: f_l,f_v,f_m,d,v

  if (N_states == 1 .or. N_det == 1) then
    return
  endif

  print*,''
  print*,'# Oscillator strength:'
  print*,'=============================================='

  if (print_all_transitions) then
    n_states_print = N_states
  else
   n_states_print = 1
  endif

  write(*,'(A103)') '  Oscillator strength in length gauge (f_l), velocity gauge (f_v) and mixed length-velocity gauge (f_m)'
  do jstate = 1, n_states_print !N_states
    do istate = jstate + 1, N_states
      d = multi_s_dipole_moment(istate,jstate)
      v = multi_s_deriv_1(istate,jstate)
      ! Length gauge
      f_l = 2d0/3d0 * d * d * dabs(ci_energy(istate) - ci_energy(jstate))
      ! Velocity gauge
      f_v = 2d0/3d0 * v * v * 1d0/dabs(ci_energy(istate) - ci_energy(jstate))
      ! Mixed gauge
      f_m = 2d0/3d0 * d * v

      write(*,'(A19,I3,A9,F10.6,A5,F7.1,A10,F9.6,A6,F9.6,A6,F9.6,A8,F7.3)') '   #  Transition n.', (istate-1), ': Excit.=', dabs((ci_energy(istate) - ci_energy(jstate)))*au2eV, &
      ' eV (',dabs((ci_energy(istate) - ci_energy(jstate)))*Ha2nm,' nm), f_l=',f_l, ', f_v=', f_v, ', f_m=', f_m, ', <S^2>=', s2_values(istate)
      write(*,'(I4,I4,A4,I3,A6,F6.1,A6,F6.1)') (istate-1), (jstate-1), '  ->', (istate-1), ', %T1=', percent_exc(2,istate), ', %T2=',percent_exc(3,istate)
  
      ! Print the first det of each state
      if (print_det_state) then
        call print_state(jstate)
        call print_state(istate)
      endif

    enddo
  enddo

  print*,'=============================================='
  print*,''

end
