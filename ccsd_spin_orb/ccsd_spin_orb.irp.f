! Prog

program ccsd

  implicit none

  BEGIN_DOC
  ! CCSD in spin orbitals
  END_DOC

  call run
  
end

! Code

subroutine run

  implicit none

  BEGIN_DOC
  ! CCSD in spin orbitals
  END_DOC

  double precision, allocatable :: t1(:,:), t2(:,:,:,:), tau(:,:,:,:), tau_t(:,:,:,:)
  double precision, allocatable :: r1(:,:), r2(:,:,:,:)
  double precision, allocatable :: cF_oo(:,:), cF_ov(:,:), cF_vv(:,:)
  double precision, allocatable :: cW_oooo(:,:,:,:), cW_ovvo(:,:,:,:), cW_vvvv(:,:,:,:)
  
  double precision, allocatable :: f_oo(:,:), f_ov(:,:), f_vv(:,:), f_o(:), f_v(:)
  double precision, allocatable :: v_oooo(:,:,:,:), v_vooo(:,:,:,:), v_ovoo(:,:,:,:)
  double precision, allocatable :: v_oovo(:,:,:,:), v_ooov(:,:,:,:), v_vvoo(:,:,:,:)
  double precision, allocatable :: v_vovo(:,:,:,:), v_voov(:,:,:,:), v_ovvo(:,:,:,:)
  double precision, allocatable :: v_ovov(:,:,:,:), v_oovv(:,:,:,:), v_vvvo(:,:,:,:)
  double precision, allocatable :: v_vvov(:,:,:,:), v_vovv(:,:,:,:), v_ovvv(:,:,:,:)
  double precision, allocatable :: v_vvvv(:,:,:,:)

  double precision, allocatable :: all_err2(:,:), all_t2(:,:)
  double precision, allocatable :: err2(:,:,:,:), tmp_err2(:), tmp_t2(:)
  double precision, allocatable :: all_err1(:,:), all_t1(:,:)
  double precision, allocatable :: err1(:,:), tmp_err1(:), tmp_t1(:) 

  logical                       :: not_converged
  integer, allocatable          :: list_occ(:,:), list_vir(:,:)
  integer                       :: nO,nV,nOa,nOb,nVa,nVb,nO_m,nV_m,nO_S(2),nV_S(2),n_spin(4)
  integer                       :: nb_iter, i,j,a,b
  double precision              :: energy, max_r, max_r1, max_r2, cc, ta, tb

  ! Extract number of occ/vir alpha/beta spin orbitals
  call extract_n_spin(n_spin)
  nOa = n_spin(1)
  nOb = n_spin(2)
  nVa = n_spin(3)
  nVb = n_spin(4)

  ! Total number of occ/vir spin orb
  nO = nOa + nOb
  nV = nVa + nVb
  !print*,nO,nV

  ! Number of occ/vir spin orb per spin
  nO_S = (/nOa,nOb/)
  nV_S = (/nVa,nVb/)
  !print*,nO_S,nV_S

  ! Maximal number of occ/vir 
  nO_m = max(nOa, nOb)
  nV_m = max(nVa, nVb)
  !print*,nO_m,nV_m
  
  allocate(list_occ(nO_m,2), list_vir(NV_m,2))
  call extract_list_orb(nO_m,nV_m,list_occ,list_vir)
  !print*,list_occ(:,1)
  !print*,list_occ(:,2)
  !print*,list_vir(:,1)
  !print*,list_vir(:,2)

  ! Allocation
  allocate(t1(nO,nV), t2(nO,nO,nV,nV), tau(nO,nO,nV,nV), tau_t(nO,nO,nV,nV))
  allocate(r1(nO,nV), r2(nO,nO,nV,nV))
  allocate(cF_oo(nO,nO), cF_ov(nO,nV), cF_vv(nV,nV))
  allocate(cW_oooo(nO,nO,nV,nV), cW_ovvo(nO,nV,nV,nO), cW_vvvv(nV,nV,nV,nV))
  allocate(v_oooo(nO,nO,nO,nO))
  allocate(v_vooo(nV,nO,nO,nO))
  allocate(v_ovoo(nO,nV,nO,nO))
  allocate(v_oovo(nO,nO,nV,nO))
  allocate(v_ooov(nO,nO,nO,nV))
  allocate(v_vvoo(nV,nV,nO,nO))
  allocate(v_vovo(nV,nO,nV,nO))
  allocate(v_voov(nV,nO,nO,nV))
  allocate(v_ovvo(nO,nV,nV,nO))
  allocate(v_ovov(nO,nV,nO,nV))
  allocate(v_oovv(nO,nO,nV,nV))
  allocate(v_vvvo(nV,nV,nV,nO))
  allocate(v_vvov(nV,nV,nO,nV))
  allocate(v_vovv(nV,nO,nV,nV))
  allocate(v_ovvv(nO,nV,nV,nV))
  allocate(v_vvvv(nV,nV,nV,nV))
  allocate(f_o(nO), f_v(nV))
  allocate(f_oo(nO, nO))
  allocate(f_ov(nO, nV))
  allocate(f_vv(nV, nV))
  
  ! Allocation for the diis
  if (cc_update_method == 'diis') then
    allocate(all_err2(nO*nO*nV*nV,cc_diis_depth), all_t2(nO*nO*nV*nV,cc_diis_depth))
    allocate(err2(nO,nO,nV,nV), tmp_err2(nO*nO*nV*nV), tmp_t2(nO*nO*nV*nV))
    all_err2 = 0d0
    all_t2   = 0d0
    allocate(all_err1(nO*nV,cc_diis_depth), all_t1(nO*nV,cc_diis_depth))
    allocate(err1(nO,nV), tmp_err1(nO*nV), tmp_t1(nO*nV))
    all_err1 = 0d0
    all_t1   = 0d0
  endif

  ! Fock elements
  call gen_f_ints(nO_m,nO_m, nO_S,nO_S, list_occ,list_occ, nO,nO, f_oo)
  call gen_f_ints(nO_m,nV_m, nO_S,nV_S, list_occ,list_vir, nO,nV, f_ov)
  call gen_f_ints(nV_m,nV_m, nV_S,nV_S, list_vir,list_vir, nV,nV, f_vv)

  ! Diag elements
  do i = 1, nO
    f_o(i) = f_oo(i,i)
  enddo
  do i = 1, nV
    f_v(i) = f_vv(i,i)
  enddo

  ! Bi electronic integrals from list
  ! OOOO
  call gen_v_ints(nO_m,nO_m,nO_m,nO_m, nO_S,nO_S,nO_S,nO_S, list_occ,list_occ,list_occ,list_occ, nO,nO,nO,nO, v_oooo)

  ! OOO V
  call gen_v_ints(nV_m,nO_m,nO_m,nO_m, nV_S,nO_S,nO_S,nO_S, list_vir,list_occ,list_occ,list_occ, nV,nO,nO,nO, v_vooo)
  call gen_v_ints(nO_m,nV_m,nO_m,nO_m, nO_S,nV_S,nO_S,nO_S, list_occ,list_vir,list_occ,list_occ, nO,nV,nO,nO, v_ovoo)
  call gen_v_ints(nO_m,nO_m,nV_m,nO_m, nO_S,nO_S,nV_S,nO_S, list_occ,list_occ,list_vir,list_occ, nO,nO,nV,nO, v_oovo)
  call gen_v_ints(nO_m,nO_m,nO_m,nV_m, nO_S,nO_S,nO_S,nV_S, list_occ,list_occ,list_occ,list_vir, nO,nO,nO,nV, v_ooov)

  ! OO VV
  call gen_v_ints(nV_m,nV_m,nO_m,nO_m, nV_S,nV_S,nO_S,nO_S, list_vir,list_vir,list_occ,list_occ, nV,nV,nO,nO, v_vvoo)
  call gen_v_ints(nV_m,nO_m,nV_m,nO_m, nV_S,nO_S,nV_S,nO_S, list_vir,list_occ,list_vir,list_occ, nV,nO,nV,nO, v_vovo)
  call gen_v_ints(nV_m,nO_m,nO_m,nV_m, nV_S,nO_S,nO_S,nV_S, list_vir,list_occ,list_occ,list_vir, nV,nO,nO,nV, v_voov)
  call gen_v_ints(nO_m,nV_m,nV_m,nO_m, nO_S,nV_S,nV_S,nO_S, list_occ,list_vir,list_vir,list_occ, nO,nV,nV,nO, v_ovvo)
  call gen_v_ints(nO_m,nV_m,nO_m,nV_m, nO_S,nV_S,nO_S,nV_S, list_occ,list_vir,list_occ,list_vir, nO,nV,nO,nV, v_ovov)
  call gen_v_ints(nO_m,nO_m,nV_m,nV_m, nO_S,nO_S,nV_S,nV_S, list_occ,list_occ,list_vir,list_vir, nO,nO,nV,nV, v_oovv)

  ! O VVV
  call gen_v_ints(nV_m,nV_m,nV_m,nO_m, nV_S,nV_S,nV_S,nO_S, list_vir,list_vir,list_vir,list_occ, nV,nV,nV,nO, v_vvvo)
  call gen_v_ints(nV_m,nV_m,nO_m,nV_m, nV_S,nV_S,nO_S,nV_S, list_vir,list_vir,list_occ,list_vir, nV,nV,nO,nV, v_vvov)
  call gen_v_ints(nV_m,nO_m,nV_m,nV_m, nV_S,nO_S,nV_S,nV_S, list_vir,list_occ,list_vir,list_vir, nV,nO,nV,nV, v_vovv)
  call gen_v_ints(nO_m,nV_m,nV_m,nV_m, nO_S,nV_S,nV_S,nV_S, list_occ,list_vir,list_vir,list_vir, nO,nV,nV,nV, v_ovvv)

  ! VVVV
  call gen_v_ints(nV_m,nV_m,nV_m,nV_m, nV_S,nV_S,nV_S,nV_S, list_vir,list_vir,list_vir,list_vir, nV,nV,nV,nV, v_vvvv)

  ! Init of T
  t1 = 0d0
  call guess_t2(nO,nV,v_oovv,f_o,f_v,t2)
  call compute_tau(nO,nV,t1,t2,tau)
  call compute_tau_t(nO,nV,t1,t2,tau_t)
  
  ! Loop init
  nb_iter = 0
  not_converged = .True.
  r1 = 0d0
  r2 = 0d0
  max_r1 = 0d0
  max_r2 = 0d0
  call wall_time(ta)

  ! Loop
  do while (not_converged)

    call ccsd_energy(nO,nV,t1,t2,F_ov,v_oovv,energy)
    print*,''
    print*,'Iter n. :', nb_iter
    print*,'E(CCSD)= ', hf_energy + energy, energy
    print*,'r       :', max_r1, max_r2

    ! Intermediates
    call compute_cF_oo(nO,nV,t1,tau_t,F_oo,F_ov,F_vv,v_ooov,v_oovv,v_ovvv,cF_oo)
    call compute_cF_ov(nO,nV,t1,tau_t,F_oo,F_ov,F_vv,v_ooov,v_oovv,v_ovvv,cF_ov)
    call compute_cF_vv(nO,nV,t1,tau_t,F_oo,F_ov,F_vv,v_ooov,v_oovv,v_ovvv,cF_vv)
    
    call compute_cW_oooo(nO,nV,t1,t2,tau,v_oooo,v_ooov,v_oovo,v_oovv,v_ovvo,v_ovvv,v_vovv,v_vvvv,cW_oooo)
    call compute_cW_ovvo(nO,nV,t1,t2,tau,v_oooo,v_ooov,v_oovo,v_oovv,v_ovvo,v_ovvv,v_vovv,v_vvvv,cW_ovvo)
    call compute_cW_vvvv(nO,nV,t1,t2,tau,v_oooo,v_ooov,v_oovo,v_oovv,v_ovvo,v_ovvv,v_vovv,v_vvvv,cW_vvvv)

    ! Residuals
    call compute_r1(nO,nV,t1,t2,f_o,f_v,F_ov,cF_oo,cF_ov,cF_vv,v_oovo,v_ovov,v_ovvv,r1)
    call compute_r2(nO,nV,t1,t2,tau,f_o,f_v,cF_oo,cF_ov,cF_vv,cW_oooo,cW_vvvv,cW_ovvo,v_ovoo,v_oovv,v_ovvo,v_vvvo,r2)

    ! Max elements in the residuals
    max_r1 = maxval(abs(r1(:,:)))
    max_r2 = maxval(abs(r2(:,:,:,:)))
    max_r  = max(max_r1,max_r2)

    ! Update
    ! With DIIS
    if (cc_update_method == 'diis') then

      ! DIIS T1, it is not always good since the t1 can be small
      ! That's why there is a call to update the t1 in the standard way
      ! T1 error tensor
      !do a = 1, nV
      !  do i = 1, nO
      !    err1(i,a) = - r1(i,a) / (f_o(i) - f_v(a))
      !  enddo
      !enddo
      ! Transfo errors and parameters in vectors
      !tmp_err1 = reshape(err1,(/nO*nV/))
      !tmp_t1   = reshape(t1  ,(/nO*nV/))
      ! Add the error and parameter vectors with those of the previous iterations
      !call update_all_err(tmp_err1,all_err1,nO*nV,cc_diis_depth,nb_iter+1)
      !call update_all_t  (tmp_t1  ,all_t1  ,nO*nV,cc_diis_depth,nb_iter+1)
      ! Diis and reshape T as a tensor
      !call diis_cc(err1,all_err1,tmp_t1,all_t1,nO*nV,cc_diis_depth,nb_iter+1)
      !t1 = reshape(tmp_t1  ,(/nO,nV/))
      call update_t1(nO,nV,r1,f_o,f_v,t1)

      ! DIIS T2
      ! T2 error tensor
      do b = 1, nV
        do a = 1, nV
          do j = 1, nO
            do i = 1, nO
              err2(i,j,a,b) = - r2(i,j,a,b) / (f_o(i)+f_o(j)-f_v(a)-f_v(b))
            enddo
          enddo
        enddo
      enddo

      ! Transfo errors and parameters in vectors
      tmp_err2 = reshape(err2,(/nO*nO*nV*nV/))
      tmp_t2   = reshape(t2  ,(/nO*nO*nV*nV/))
      ! Add the error and parameter vectors with those of the previous iterations
      call update_all_err(tmp_err2,all_err2,nO*nO*nV*nV,cc_diis_depth,nb_iter+1)
      call update_all_t  (tmp_t2  ,all_t2  ,nO*nO*nV*nV,cc_diis_depth,nb_iter+1)
      ! Diis and reshape T as a tensor
      call diis_cc(err2,all_err2,tmp_t2,all_t2,nO*nO*nV*nV,cc_diis_depth,nb_iter+1)
      t2 = reshape(tmp_t2  ,(/nO,nO,nV,nV/))

    ! Standard update as T = T - Delta
    elseif (cc_update_method == 'none') then
       
      call update_t1(nO,nV,r1,f_o,f_v,t1)
      call update_t2(nO,nV,r2,f_o,f_v,t2)

    else
      print*,'Unkonw cc_method_method: '//cc_update_method
    endif

    ! Update T intermediates
    call compute_tau(nO,nV,t1,t2,tau)
    call compute_tau_t(nO,nV,t1,t2,tau_t)

    ! Convergence
    nb_iter = nb_iter + 1
    if (max_r < cc_thresh_conv .or. nb_iter > cc_max_iter) then
      not_converged = .False.
    endif

  enddo
  call wall_time(tb)
  print*,'Time:',tb-ta

  ! Deallocate
  deallocate(t1,t2,tau,tau_t)
  deallocate(r1,r2)
  deallocate(cF_oo,cF_ov,cF_vv)
  deallocate(cW_oooo,cW_ovvo,cW_vvvv)
  deallocate(f_oo,f_ov,f_vv,f_o,f_v)
  deallocate(v_oooo)
  deallocate(v_vooo,v_ovoo,v_oovo,v_ooov)
  deallocate(v_vvoo,v_vovo,v_voov,v_ovvo,v_ovov,v_oovv)
  deallocate(v_ovvv,v_vovv,v_vvov,v_vvvo)
  deallocate(v_vvvv)
  
end

! Energy

subroutine ccsd_energy(nO,nV,t1,t2,Fov,v_oovv,energy)

  implicit none

  BEGIN_DOC
  ! CCSD energy in spin orbitals
  END_DOC

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)
  double precision,intent(in)   :: Fov(nO,nV)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)

  double precision,intent(out)  :: energy

  integer                       :: i,j,a,b


  energy = 0d0

  do i=1,nO
      do a=1,nV
      energy = energy + Fov(i,a) * t1(i,a)
    end do
  end do

  do i=1,nO
    do j=1,nO
      do a=1,nV
        do b=1,nV
          energy = energy                                & 
                 + 0.5d0 * v_oovv(i,j,a,b) * t1(i,a) * t1(j,b) &
                 + 0.25d0 * v_oovv(i,j,a,b) * t2(i,j,a,b)
        end do
      end do
    end do
  end do

end

! T2

subroutine guess_t2(nO,nV,v_oovv,f_o,f_v,t2)

  implicit none

  integer, intent(in)           :: nO,nV
  double precision, intent(in)  :: v_oovv(nO,nO,nV,nV), f_o(nO), f_v(nV)
  
  double precision, intent(out) :: t2(nO,nO,nV,nV)

  integer :: i,j,a,b

  do b = 1, nV
    do a = 1, nV
      do j = 1, nO
        do i = 1, nO
          t2(i,j,a,b) = v_oovv(i,j,a,b) / (f_o(i)+f_o(j)-f_v(a)-f_v(b))
        enddo
      enddo
    enddo
  enddo

end

! T1

subroutine update_t1(nO,nV,r1,f_o,f_v,t1)

  implicit none

  integer, intent(in)           :: nO,nV
  double precision, intent(in)  :: r1(nO,nV), f_o(nO), f_v(nV)
  
  double precision, intent(out) :: t1(nO,nV)

  integer :: i,a

  do a = 1, nV
    do i = 1, nO
      t1(i,a) = t1(i,a) - r1(i,a) / (f_o(i)-f_v(a))
    enddo
  enddo

end

! T2

subroutine update_t2(nO,nV,r2,f_o,f_v,t2)

  implicit none

  integer, intent(in)           :: nO,nV
  double precision, intent(in)  :: r2(nO,nO,nV,nV), f_o(nO),f_v(nV)
  
  double precision, intent(out) :: t2(nO,nO,nV,nV)

  integer :: i,j,a,b

  do b = 1, nV
    do a = 1, nV
      do j = 1, nO
        do i = 1, nO
          t2(i,j,a,b) = t2(i,j,a,b) - r2(i,j,a,b) / (f_o(i)+f_o(j)-f_v(a)-f_v(b))
        enddo
      enddo
    enddo
  enddo

end

! Tau

subroutine compute_tau(nO,nV,t1,t2,tau)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)

  double precision,intent(out)  :: tau(nO,nO,nV,nV)
  
  integer                       :: i,j,k,l
  integer                       :: a,b,c,d

  do i=1,nO
    do j=1,nO
      do a=1,nV
        do b=1,nV
          tau(i,j,a,b) = t2(i,j,a,b) + t1(i,a)*t1(j,b) - t1(i,b)*t1(j,a)
        enddo
      enddo
    enddo
  enddo

end

! Tau_t

subroutine compute_tau_t(nO,nV,t1,t2,tau_t)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)

  double precision,intent(out)  :: tau_t(nO,nO,nV,nV)

  integer                       :: i,j,k,l
  integer                       :: a,b,c,d

  do i=1,nO
    do j=1,nO
      do a=1,nV
        do b=1,nV
          tau_t(i,j,a,b) = t2(i,j,a,b) + 0.5d0*(t1(i,a)*t1(j,b) - t1(i,b)*t1(j,a))
        enddo
      enddo
    enddo
  enddo

end

! R1

subroutine compute_r1(nO,nV,t1,t2,f_o,f_v,Fov,cF_oo,cF_ov,cF_vv,v_oovo,v_ovov,v_ovvv,r1)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)
  double precision,intent(in)   :: f_o(nO), f_v(nV)
  double precision,intent(in)   :: Fov(nO,nV)
  double precision,intent(in)   :: cF_oo(nO,nO)
  double precision,intent(in)   :: cF_ov(nO,nV)
  double precision,intent(in)   :: cF_vv(nV,nV)
  double precision,intent(in)   :: v_oovo(nO,nO,nV,nO)
  double precision,intent(in)   :: v_ovov(nO,nV,nO,nV)
  double precision,intent(in)   :: v_ovvv(nO,nV,nV,nV)

  double precision,intent(out)  :: r1(nO,nV)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f

  do a = 1, nV
    do i = 1, nO
      r1(i,a) = Fov(i,a)
    enddo
  enddo

  !do a=1,nV
  !  do i=1,nO
  !    do e=1,nV
  !      r1(i,a) = r1(i,a) + t1(i,e)*cF_vv(a,e)
  !    end do
  !  end do
  !end do
  call dgemm('N','T', nO, nV, nV, &
             1d0, t1   , size(t1,1), &
                  cF_vv, size(cF_vv,1), &
             1d0, r1   , size(r1,1))

  !do a=1,nV
  !  do i=1,nO
  !    do m=1,nO
  !      r1(i,a) = r1(i,a) - t1(m,a)*cF_oo(m,i)
  !    end do
  !  end do
  !end do
  call dgemm('T','N', nO, nV, nO, &
             -1d0, cF_oo, size(cF_oo,1), &
                   t1   , size(t1,1), &
              1d0, r1   , size(r1,1))

  do a=1,nV
    do i=1,nO
      do e=1,nV
        do m=1,nO
          r1(i,a) = r1(i,a) + t2(i,m,a,e)*cF_ov(m,e)
        end do
      end do
    end do
  end do

  do a=1,nV
    do i=1,nO
      do f=1,nV
        do n=1,nO
          r1(i,a) = r1(i,a) - t1(n,f)*v_ovov(n,a,i,f)
        end do
      end do
    end do
  end do

  !do a=1,nV
  !  do i=1,nO
  !    do f=1,nV
  !      do e=1,nV
  !        do m=1,nO
  !          r1(i,a) = r1(i,a) - 0.5d0*t2(i,m,e,f)*v_ovvv(m,a,e,f)
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: X_vovv(:,:,:,:)
  allocate(X_vovv(nV,nO,nV,nV))
  do f = 1, nV
    do e = 1, nV
       do m = 1, nO
         do a = 1, nV
           X_vovv(a,m,e,f) = v_ovvv(m,a,e,f)
        enddo
      enddo
    enddo
  enddo
  call dgemm('N','T', nO, nV, nO*nV*nV, &
             -0.5d0, t2    , size(t2,1), &
                     X_vovv, size(X_vovv,1), &
              1d0  , r1    , size(r1,1))
  
  deallocate(X_vovv)

  !do a=1,nV
  !  do i=1,nO
  !    do e=1,nV
  !      do m=1,nO
  !        do n=1,nO
  !          r1(i,a) = r1(i,a) - 0.5d0*t2(m,n,a,e)*v_oovo(n,m,e,i)
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: X_oovv(:,:,:,:)
  allocate(X_oovv(nO,nO,nV,nV))
  do a = 1, nV
    do e = 1, nV
      do m = 1, nO
        do n = 1, nO
          X_oovv(n,m,e,a) = t2(m,n,a,e)
        enddo
      enddo
    enddo
  enddo
  call dgemm('T','N', nO, nV, nO*nO*nV, &
             -0.5d0, v_oovo, size(v_oovo,1) * size(v_oovo,2) * size(v_oovo,3), &
                     X_oovv, size(X_oovv,1) * size(X_oovv,2) * size(X_oovv,3), &
             1d0   , r1    , size(r1,1))
  
  deallocate(X_oovv)

  do a = 1, nV
    do i = 1, nO
      r1(i,a) = (f_o(i)-f_v(a)) * t1(i,a) - r1(i,a)
    enddo
  enddo

end

! R2

subroutine compute_r2(nO,nV,t1,t2,tau,f_o,f_v,cF_oo,cF_ov,cF_vv,cW_oooo,cW_vvvv,cW_ovvo,v_ovoo,v_oovv,v_ovvo,v_vvvo,r2)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: cF_oo(nO,nO)
  double precision,intent(in)   :: cF_ov(nO,nV)
  double precision,intent(in)   :: cF_vv(nV,nV)
  double precision,intent(in)   :: f_o(nO), f_v(nV)
  double precision,intent(in)   :: cW_oooo(nO,nO,nO,nO)
  double precision,intent(in)   :: cW_vvvv(nV,nV,nV,nV)
  double precision,intent(in)   :: cW_ovvo(nO,nV,nV,nO)
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)
  double precision,intent(in)   :: tau(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovoo(nO,nV,nO,nO)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovvo(nO,nV,nV,nO)
  double precision,intent(in)   :: v_vvvo(nV,nV,nV,nO)

  double precision,intent(out)  :: r2(nO,nO,nV,nV)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f
  double precision, allocatable :: X_vvov(:,:,:,:), X_vvoo(:,:,:,:)
  double precision, allocatable :: A_vvov(:,:,:,:)
  double precision, allocatable :: X_oovv(:,:,:,:), Y_oovv(:,:,:,:)
  double precision, allocatable :: A_vvoo(:,:,:,:), B_ovoo(:,:,:,:), C_ovov(:,:,:,:)
  double precision, allocatable :: A_ovov(:,:,:,:), B_ovvo(:,:,:,:), X_ovvo(:,:,:,:)

  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = v_oovv(i,j,a,b)
        end do
      end do
    end do
  end do

  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do e=1,nV
  !          r2(i,j,a,b) = r2(i,j,a,b) + t2(i,j,a,e)*cF_vv(b,e)
  !          r2(i,j,a,b) = r2(i,j,a,b) - t2(i,j,b,e)*cF_vv(a,e)
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  allocate(X_oovv(nO,nO,nV,nV))
  call dgemm('N','T',nO*nO*nV, nV, nV, &
             1d0, t2    , size(t2,1) * size(t2,2) * size(t2,3), &
                  cF_VV , size(cF_vv,1), &
             0d0, X_oovv, size(X_oovv,1) * size(X_oovv,2) * size(X_oovv,3))

  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = r2(i,j,a,b) + X_oovv(i,j,a,b) - X_oovv(i,j,b,a)
        end do
      end do
    end do
  end do
  deallocate(X_oovv)

  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do e=1,nV
  !          do m=1,nO
  !            r2(i,j,a,b) = r2(i,j,a,b) - 0.5d0*t2(i,j,a,e)*t1(m,b)*cF_ov(m,e)
  !            r2(i,j,a,b) = r2(i,j,a,b) + 0.5d0*t2(i,j,b,e)*t1(m,a)*cF_ov(m,e)
  !          end do
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: A_vv(:,:)
  allocate(A_vv(nV,nV), X_oovv(nO,nO,nV,nV))
  call dgemm('T','N', nV, nV, nO, &
             1d0, t1   , size(t1,1), &
                  cF_ov, size(cF_ov,1), &
             0d0, A_vv , size(A_vv,1))

  call dgemm('N','T', nO*nO*nV, nV, nV, &
             0.5d0, t2    , size(t2,1) * size(t2,2) * size(t2,3), &
                    A_vv  , size(A_vv,1), &
             0d0  , X_oovv, size(X_oovv,1) * size(X_oovv,2) * size(X_oovv,3))
  
  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = r2(i,j,a,b) - X_oovv(i,j,a,b) + X_oovv(i,j,b,a) 
        end do
      end do
    end do
  end do
             
  deallocate(A_vv,X_oovv)

  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do m=1,nO
  !          r2(i,j,a,b) = r2(i,j,a,b) - t2(i,m,a,b)*cF_oo(m,j)
  !          r2(i,j,a,b) = r2(i,j,a,b) + t2(j,m,a,b)*cF_oo(m,i)
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  allocate(X_oovv(nO,nO,nV,nV), Y_oovv(nO,nO,nV,nV))
  do b=1,nV
    do a=1,nV
      do i=1,nO
        do m=1,nO
          X_oovv(m,i,a,b) = t2(i,m,a,b)
        end do
      end do
    end do
  end do

  call dgemm('T','N', nO, nO*nV*nV, nO, &
             1d0, cF_oo , size(cF_oo,1), &
                  X_oovv, size(X_oovv,1), &
             0d0, Y_oovv, size(Y_oovv,1))

  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = r2(i,j,a,b) - Y_oovv(j,i,a,b) + Y_oovv(i,j,a,b) 
        end do
      end do
    end do
  end do
  deallocate(X_oovv,Y_oovv)

  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do e=1,nV
  !          do m=1,nO
  !            r2(i,j,a,b) = r2(i,j,a,b) - 0.5d0*t2(i,m,a,b)*t1(j,e)*cF_ov(m,e)
  !            r2(i,j,a,b) = r2(i,j,a,b) + 0.5d0*t2(j,m,a,b)*t1(i,e)*cF_ov(m,e)
  !          end do
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: A_oo(:,:), B_oovv(:,:,:,:)
  allocate(A_oo(nO,nO),B_oovv(nO,nO,nV,nV),X_oovv(nO,nO,nV,nV))
  call dgemm('N','T', nO, nO, nV, &
        1d0, t1   , size(t1,1), &
             cF_ov, size(cF_ov,1), &
        0d0, A_oo , size(A_oo,1))
  do b = 1, nV
    do a = 1, nV
      do i = 1, nO
        do m = 1, nO
          B_oovv(m,i,a,b) = t2(i,m,a,b)
        enddo
      enddo
    enddo
  enddo
  call dgemm('N','N', nO, nO*nV*nV, nO, &
             0.5d0, A_oo, size(A_oo,1), &
                    B_oovv, size(B_oovv,1), &
             0d0  , X_oovv, size(X_oovv,1))
  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = r2(i,j,a,b) - X_oovv(j,i,a,b) + X_oovv(i,j,a,b)
        end do
      end do
    end do
  end do
  deallocate(A_oo,B_oovv,X_oovv)

  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do n=1,nO
  !          do m=1,nO
  !            r2(i,j,a,b) = r2(i,j,a,b) + 0.5d0*tau(m,n,a,b)*cW_oooo(m,n,i,j)
  !          end do
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  call dgemm('T','N', nO*nO, nV*nV, nO*nO, &
             0.5d0, cW_oooo, size(cW_oooo,1) * size(cW_oooo,2), &
                    tau    , size(tau,1) * size(tau,2), &
             1d0  , r2     , size(r2,1) * size(r2,2))
  
  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do f=1,nV
  !          do e=1,nV
  !            r2(i,j,a,b) = r2(i,j,a,b) + 0.5d0*tau(i,j,e,f)*cW_vvvv(a,b,e,f)
  !          end do
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  call dgemm('N','T', nO*nO, nV*nV, nV*nV, &
             0.5d0, tau    , size(tau,1) * size(tau,2), &
                    cW_vvvv, size(cW_vvvv,1) * size(cW_vvvv,2), &
             1d0  , r2     , size(r2,1) * size(r2,2))
  
  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do e=1,nV
  !          do m=1,nO
  !            r2(i,j,a,b) = r2(i,j,a,b)                                                 & 
  !                        + t2(i,m,a,e)*cW_ovvo(m,b,e,j) &
  !                        - t2(j,m,a,e)*cW_ovvo(m,b,e,i) &
  !                        - t2(i,m,b,e)*cW_ovvo(m,a,e,j) &
  !                        + t2(j,m,b,e)*cW_ovvo(m,a,e,i) &
  !                        - t1(i,e)*t1(m,a)*v_ovvo(m,b,e,j) &
  !                        + t1(j,e)*t1(m,a)*v_ovvo(m,b,e,i) &
  !                        + t1(i,e)*t1(m,b)*v_ovvo(m,a,e,j) &
  !                        - t1(j,e)*t1(m,b)*v_ovvo(m,a,e,i)
  !          end do
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  allocate(A_ovov(nO,nV,nO,nV), B_ovvo(nO,nV,nV,nO), X_ovvo(nO,nV,nV,nO))
  do a = 1, nV
    do i = 1, nO
      do e = 1, nV
        do m = 1, nO
          A_ovov(m,e,i,a) = t2(i,m,a,e)
        end do
      end do
    end do
  end do
  do j = 1, nO
    do b = 1, nV
      do e = 1, nV
        do m = 1, nO
          B_ovvo(m,e,b,j) = cW_ovvo(m,b,e,j) 
        enddo
      enddo
    enddo
  enddo
  
  call dgemm('T','N', nO*nV, nV*nO, nO*nV, &
             1d0, A_ovov, size(A_ovov,1) * size(A_ovov,2), &
                  B_ovvo, size(B_ovvo,1) * size(B_ovvo,2), &
             0d0, X_ovvo, size(X_ovvo,1) * size(X_ovvo,2))
  do b = 1, nV
    do a = 1, nV
      do j = 1, nO
        do i = 1, nO
          r2(i,j,a,b) = r2(i,j,a,b) + X_ovvo(i,a,b,j) - X_ovvo(j,a,b,i) &
                                    - X_ovvo(i,b,a,j) + X_ovvo(j,b,a,i)
        enddo
      enddo
    enddo
  enddo
  deallocate(A_ovov,B_ovvo,X_ovvo)
  allocate(A_vvoo(nV,nV,nO,nO), B_ovoo(nO,nV,nO,nO), C_ovov(nO,nV,nO,nV))
  do m = 1, nO
    do j = 1, nO
      do b = 1, nV
        do e = 1, nV
          A_vvoo(e,b,j,m) = v_ovvo(m,b,e,j)
        enddo
      enddo
    enddo
  enddo
  call dgemm('N','N', nO, nV*nO*nO, nV, &
             1d0, t1    , size(t1,1), &
                  A_vvoo, size(A_vvoo,1), &
             0d0, B_ovoo, size(B_ovoo,1))
  call dgemm('N','N', nO*nV*nO, nV, nO, &
             1d0, B_ovoo, size(B_ovoo,1) * size(B_ovoo,2) * size(B_ovoo,3), &
                  t1    , size(t1,1), &
             0d0, C_ovov, size(C_ovov,1) * size(C_ovov,2) * size(C_ovov,3))
  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = r2(i,j,a,b) - C_ovov(i,b,j,a) + C_ovov(j,b,i,a) &
                                    + C_ovov(i,a,j,b) - C_ovov(j,a,i,b)
        end do
      end do
    end do
  end do
  deallocate(A_vvoo, B_ovoo, C_ovov)
                  
  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do e=1,nV
  !          r2(i,j,a,b) = r2(i,j,a,b) + t1(i,e)*v_vvvo(a,b,e,j) - t1(j,e)*v_vvvo(a,b,e,i)
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  allocate(A_vvov(nV,nV,nO,nV), X_vvoo(nV,nV,nO,nO))
  do e = 1, nV
    do j = 1, nO
      do b = 1, nV
        do a = 1, nV
          A_vvov(a,b,j,e) = v_vvvo(a,b,e,j)
        enddo
      enddo
    enddo
  enddo

  call dgemm('N','T', nV*nV*nO, nO, nV, &
             1d0, A_vvov, size(A_vvov,1) * size(A_vvov,2) * size(A_vvov,3), &
                  t1    , size(t1,1), &
             0d0, X_vvoo, size(X_vvoo,1) * size(X_vvoo,2) * size(X_vvoo,3))

  do b = 1, nV
    do a = 1, nV
      do j = 1, nO
        do i = 1, NO
           r2(i,j,a,b ) = r2(i,j,a,b) + X_vvoo(a,b,j,i) - X_vvoo(a,b,i,j)
        enddo
      enddo
    enddo
  enddo
  deallocate(A_vvov,X_vvoo)

  !do b=1,nV
  !  do a=1,nV
  !    do j=1,nO
  !      do i=1,nO

  !        do m=1,nO
  !          r2(i,j,a,b) = r2(i,j,a,b) - t1(m,a)*v_ovoo(m,b,i,j) + t1(m,b)*v_ovoo(m,a,i,j)
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  allocate(X_vvoo(nV,nV,nO,nO))
  call dgemm('T','N', nV, nV*nO*nO, nO, &
             1d0, t1    , size(t1,1), &
                  v_ovoo, size(v_ovoo,1), &
             0d0, X_vvoo, size(X_vvoo,1))

  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = r2(i,j,a,b) - X_vvoo(a,b,i,j) + X_vvoo(b,a,i,j)
        end do
      end do
    end do
  end do
  deallocate(X_vvoo)

  do b=1,nV
    do a=1,nV
      do j=1,nO
        do i=1,nO
          r2(i,j,a,b) = (f_o(i)+f_o(j)-f_v(a)-f_v(b)) * t2(i,j,a,b) - r2(i,j,a,b)
        end do
      end do
    end do
  end do

end

! cF_oo

subroutine compute_cF_oo(nO,nV,t1,tau_t,Foo,Fov,Fvv,v_ooov,v_oovv,v_ovvv,cF_oo)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: tau_t(nO,nO,nV,nV)
  double precision,intent(in)   :: Foo(nO,nO)
  double precision,intent(in)   :: Fov(nO,nV)
  double precision,intent(in)   :: Fvv(nV,nV)
  double precision,intent(in)   :: v_ooov(nO,nO,nO,nV)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovvv(nO,nV,nV,nV)

  double precision,intent(out)  :: cF_oo(nO,nO)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f
  double precision,external     :: Kronecker_Delta

  do i=1,nO
    do m=1,nO
      cF_oo(m,i) = (1d0 - Kronecker_delta(m,i))*Foo(m,i) 
    end do
  end do

  !do i=1,nO
  !  do m=1,nO
  !    do e=1,nV
  !      cF_oo(m,i) = cF_oo(m,i) + 0.5d0*t1(i,e)*Fov(m,e)
  !    end do
  !  end do
  !end do
  call dgemm('N','T', nO, nO, nV,&
             0.5d0, Fov  , size(Fov,1), &
                    t1   , size(t1,1), &
             1d0  , cF_oo, size(cF_oo,1))

  do e=1,nV
    do n=1,nO
      do i=1,nO
        do m=1,nO
          cF_oo(m,i) = cF_oo(m,i) + t1(n,e)*v_ooov(m,n,i,e)
        end do
      end do
    end do
  end do

  !do i=1,nO
  !  do m=1,nO
  !    do f=1,nV
  !      do e=1,nV
  !        do n=1,nO
  !          cF_oo(m,i) = cF_oo(m,i) + 0.5d0*tau_t(i,n,e,f)*v_oovv(m,n,e,f)
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  call dgemm('N','T', nO, nO, nO*nV*nV, &
             0.5d0, v_oovv, size(v_oovv,1), &
                    tau_t , size(tau_t,1), &
             1d0  , cF_oo , size(cF_oo,1)) 
  
end

! cF_ov

subroutine compute_cF_ov(nO,nV,t1,tau_t,Foo,Fov,Fvv,v_ooov,v_oovv,v_ovvv,cF_ov)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: tau_t(nO,nO,nV,nV)
  double precision,intent(in)   :: Foo(nO,nO)
  double precision,intent(in)   :: Fov(nO,nV)
  double precision,intent(in)   :: Fvv(nV,nV)
  double precision,intent(in)   :: v_ooov(nO,nO,nO,nV)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovvv(nO,nV,nV,nV)

  double precision,intent(out)  :: cF_ov(nO,nV)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f
  double precision,external     :: Kronecker_Delta

  cF_ov = Fov

  do e=1,nV
    do m=1,nO
      do f=1,nV
        do n=1,nO
          cF_ov(m,e) = cF_ov(m,e) + t1(n,f)*v_oovv(m,n,e,f)
        end do
      end do
    end do
  end do
  
end

! cF_vv

subroutine compute_cF_vv(nO,nV,t1,tau_t,Foo,Fov,Fvv,v_ooov,v_oovv,v_ovvv,cF_vv)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: tau_t(nO,nO,nV,nV)
  double precision,intent(in)   :: Foo(nO,nO)
  double precision,intent(in)   :: Fov(nO,nV)
  double precision,intent(in)   :: Fvv(nV,nV)
  double precision,intent(in)   :: v_ooov(nO,nO,nO,nV)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovvv(nO,nV,nV,nV)

  double precision,intent(out)  :: cF_vv(nV,nV)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f
  double precision,external     :: Kronecker_Delta
  ! Virtual-virtual block

  do e=1,nV
    do a=1,nV
      cF_vv(a,e) = (1d0 - Kronecker_delta(a,e))*Fvv(a,e) 
    end do
  end do
 
  !do e=1,nV
  !  do a=1,nV
  !    do m=1,nO
  !      cF_vv(a,e) = cF_vv(a,e) - 0.5d0*t1(m,a)*Fov(m,e)
  !    end do
  !  end do
  !end do
  call dgemm('T','N', nV, nV, nO, &
             -0.5d0, t1   , size(t1,1), &
                     Fov  , size(Fov,1), &
              1d0  , cF_vv, size(cF_vv,1))

  !do e=1,nV
  !  do a=1,nV
  !    do m=1,nO
  !      do f=1,nV
  !        cF_vv(a,e) = cF_vv(a,e) + t1(m,f)*v_ovvv(m,a,f,e)
  !      end do
  !    end do
  !  end do
  !end do
  do f = 1, nV
    call dgemv('T', nO, nV*nV, &
               1d0, v_ovvv(:,:,f,:), size(v_ovvv,1), &
                    t1(:,f), 1, &
               1d0, cF_vv, 1)
  enddo

  !do e=1,nV
  !  do a=1,nV
  !    do f=1,nV
  !      do n=1,nO
  !        do m=1,nO
  !          cF_vv(a,e) = cF_vv(a,e) - 0.5d0*tau_t(m,n,a,f)*v_oovv(m,n,e,f)
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  do f = 1, nV
     call dgemm('T','N', nV, nV, nO*nO,&
                -0.5d0, tau_t(:,:,:,f) , size(tau_t,1) * size(tau_t,2), &
                        v_oovv(:,:,:,f), size(v_oovv,1) * size(v_oovv,2), &
                1d0   , cF_vv, size(cF_vv,1))
  enddo

end

! cW_oooo

subroutine compute_cW_oooo(nO,nV,t1,t2,tau,v_oooo,v_ooov,v_oovo,v_oovv,v_ovvo,v_ovvv,v_vovv,v_vvvv,cW_oooo)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)
  double precision,intent(in)   :: tau(nO,nO,nV,nV)
  double precision,intent(in)   :: v_oooo(nO,nO,nO,nO)
  double precision,intent(in)   :: v_ooov(nO,nO,nO,nV)
  double precision,intent(in)   :: v_oovo(nO,nO,nV,nO)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovvo(nO,nV,nV,nO)
  double precision,intent(in)   :: v_ovvv(nO,nV,nV,nV)
  double precision,intent(in)   :: v_vovv(nV,nO,nV,nV)
  double precision,intent(in)   :: v_vvvv(nV,nV,nV,nV)

  double precision,intent(out)  :: cW_oooo(nO,nO,nO,nO)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f
  double precision,external     :: Kronecker_Delta

  ! oooo block  

  cW_oooo = v_oooo

  !do j=1,nO
  !  do i=1,nO
  !    do n=1,nO
  !      do m=1,nO

  !        do e=1,nV
  !          cW_oooo(m,n,i,j) = cW_oooo(m,n,i,j) + t1(j,e)*v_ooov(m,n,i,e) - t1(i,e)*v_ooov(m,n,j,e)
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: X_oooo(:,:,:,:)
  allocate(X_oooo(nO,nO,nO,nO))
  call dgemm('N','T', nO*nO*nO, nO, nV, &
             1d0, v_ooov, size(v_ooov,1) * size(v_ooov,2) * size(v_ooov,3), &
                  t1    , size(t1,1), &
             0d0, X_oooo, size(X_oooo,1) * size(X_oooo,1) * size(X_oooo,3))
  do j=1,nO
    do i=1,nO
      do n=1,nO
        do m=1,nO
          cW_oooo(m,n,i,j) = cW_oooo(m,n,i,j) + X_oooo(m,n,i,j) - X_oooo(m,n,j,i)
        end do
      end do
    end do
  end do
  
  deallocate(X_oooo)
  
  !do m=1,nO
  !  do n=1,nO
  !    do i=1,nO
  !      do j=1,nO
  !         
  !        do e=1,nV
  !          do f=1,nV
  !            cW_oooo(m,n,i,j) = cW_oooo(m,n,i,j) + 0.25d0*tau(i,j,e,f)*v_oovv(m,n,e,f)
  !          end do
  !        end do

  !      end do
  !    end do
  !  end do
  !end do

  call dgemm('N','T', nO*nO, nO*nO, nV*nV, &
             0.25d0, v_oovv , size(v_oovv,1) * size(v_oovv,2), &
                     tau    , size(tau,1) * size(tau,2), &
             1.d0  , cW_oooo, size(cW_oooo,1) * size(cW_oooo,2))
  
end

! cW_ovvo

subroutine compute_cW_ovvo(nO,nV,t1,t2,tau,v_oooo,v_ooov,v_oovo,v_oovv,v_ovvo,v_ovvv,v_vovv,v_vvvv,cW_ovvo)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)
  double precision,intent(in)   :: tau(nO,nO,nV,nV)
  double precision,intent(in)   :: v_oooo(nO,nO,nO,nO)
  double precision,intent(in)   :: v_ooov(nO,nO,nO,nV)
  double precision,intent(in)   :: v_oovo(nO,nO,nV,nO)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovvo(nO,nV,nV,nO)
  double precision,intent(in)   :: v_ovvv(nO,nV,nV,nV)
  double precision,intent(in)   :: v_vovv(nV,nO,nV,nV)
  double precision,intent(in)   :: v_vvvv(nV,nV,nV,nV)

  double precision,intent(out)  :: cW_ovvo(nO,nV,nV,nO)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f
  double precision,external     :: Kronecker_Delta
  ! ovvo block

  cW_ovvo = v_ovvo

  !do m=1,nO
  !  do b=1,nV
  !    do e=1,nV
  !      do j=1,nO
  !        do f=1,nV
  !          cW_ovvo(m,b,e,j) = cW_ovvo(m,b,e,j) + t1(j,f)*v_ovvv(m,b,e,f)
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  call dgemm('N','T', nO*nV*nV, nO, nV, &
             1.d0, v_ovvv , size(v_ovvv,1) * size(v_ovvv,2) * size(v_ovvv,3), &
                   t1     , size(t1,1), &
             1.d0, cW_ovvo, size(cW_ovvo,1) * size(cW_ovvo,2) * size(cW_ovvo,3))

  !do j=1,nO
  !  do e=1,nV
  !    do b=1,nV
  !      do m=1,nO
  !        do n=1,nO
  !          cW_ovvo(m,b,e,j) = cW_ovvo(m,b,e,j) - t1(n,b)*v_oovo(m,n,e,j)
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: A_oovo(:,:,:,:), B_vovo(:,:,:,:)
  allocate(A_oovo(nO,nO,nV,nO), B_vovo(nV,nO,nV,nO))
  do j=1,nO
    do e=1,nV
      do m=1,nO
        do n=1,nO
          A_oovo(n,m,e,j) = v_oovo(m,n,e,j)
        end do
      end do
    end do
  end do
  
  call dgemm('T','N', nV, nO*nV*nO, nO, &
             1d0, t1    , size(t1,1), &
                  A_oovo, size(A_oovo,1), &
             0d0, B_vovo, size(B_vovo,1))
  
  do j=1,nO
    do e=1,nV
      do b=1,nV
        do m=1,nO
          cW_ovvo(m,b,e,j) = cW_ovvo(m,b,e,j) - B_vovo(b,m,e,j)
        end do
      end do
    end do
  end do
  deallocate(A_oovo,B_vovo)

  !do j=1,nO
  !  do e=1,nV
  !    do b=1,nV
  !      do m=1,nO
  !        do f=1,nV
  !          do n=1,nO
  !            cW_ovvo(m,b,e,j) = cW_ovvo(m,b,e,j) &
  !                            - ( 0.5d0*t2(j,n,f,b) + t1(j,f)*t1(n,b) )*v_oovv(m,n,e,f)
  !          end do
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: A_voov(:,:,:,:), B_voov(:,:,:,:), C_ovov(:,:,:,:)
  allocate(A_voov(nV,nO,nO,nV), B_voov(nV,nO,nO,nV), C_ovov(nO,nV,nO,nV))

  do b = 1, nV
    do j = 1, nO
      do n = 1, nO
        do f = 1, nV
          A_voov(f,n,j,b) = 0.5d0*t2(j,n,f,b) + t1(j,f)*t1(n,b)
        enddo
      enddo
    enddo
  enddo
  do e = 1, nV
    do m = 1, nO
      do n = 1, nO
        do f = 1, nV
          B_voov(f,n,m,e) = v_oovv(m,n,e,f)
        enddo
      enddo
    enddo
  enddo
  call dgemm('T','N', nO*nV, nV*nO, nV*nO, &
             1d0, A_voov, size(A_voov,1) * size(A_voov,2), &
                  B_voov, size(B_voov,1) * size(B_voov,2), &
             0d0, C_ovov, size(C_ovov,1) * size(C_ovov,2))

  do j = 1, nO
    do e = 1, nV
      do b = 1, nV
        do m = 1, nO
          cW_ovvo(m,b,e,j) = cW_ovvo(m,b,e,j) - C_ovov(j,b,m,e)
        enddo
      enddo
    enddo
  enddo
  deallocate(A_voov,B_voov,C_ovov)

end

! cW_vvvv

subroutine compute_cW_vvvv(nO,nV,t1,t2,tau,v_oooo,v_ooov,v_oovo,v_oovv,v_ovvo,v_ovvv,v_vovv,v_vvvv,cW_vvvv)

  implicit none

  integer,intent(in)            :: nO,nV
  double precision,intent(in)   :: t1(nO,nV)
  double precision,intent(in)   :: t2(nO,nO,nV,nV)
  double precision,intent(in)   :: tau(nO,nO,nV,nV)
  double precision,intent(in)   :: v_oooo(nO,nO,nO,nO)
  double precision,intent(in)   :: v_ooov(nO,nO,nO,nV)
  double precision,intent(in)   :: v_oovo(nO,nO,nV,nO)
  double precision,intent(in)   :: v_oovv(nO,nO,nV,nV)
  double precision,intent(in)   :: v_ovvo(nO,nV,nV,nO)
  double precision,intent(in)   :: v_ovvv(nO,nV,nV,nV)
  double precision,intent(in)   :: v_vovv(nV,nO,nV,nV)
  double precision,intent(in)   :: v_vvvv(nV,nV,nV,nV)

  double precision,intent(out)  :: cW_vvvv(nV,nV,nV,nV)

  integer                       :: i,j,m,n
  integer                       :: a,b,e,f
  double precision,external     :: Kronecker_Delta
  ! vvvv block

  cW_vvvv = v_vvvv

  !do f=1,nV
  !  do e=1,nV
  !    do b=1,nV
  !      do a=1,nV
  !        do m=1,nO
  !          cW_vvvv(a,b,e,f) = cW_vvvv(a,b,e,f) - t1(m,b)*v_vovv(a,m,e,f) + t1(m,a)*v_vovv(b,m,e,f)
  !        end do
  !      end do
  !    end do
  !  end do
  !end do
  double precision, allocatable :: A_ovvv(:,:,:,:), B_vvvv(:,:,:,:)
  allocate(A_ovvv(nO,nV,nV,nV), B_vvvv(nV,nV,nV,nV))
  do f=1,nV
    do e=1,nV
      do a=1,nV
        do m=1,nO
          A_ovvv(m,a,e,f) = v_vovv(a,m,e,f)
        end do
      end do
    end do
  end do

  call dgemm('T','N', nV, nV*nV*nV, nO, &
             1d0, t1    , size(t1,1), &
                  A_ovvv, size(A_ovvv,1), &
             0d0, B_vvvv, size(B_vvvv,1))
  do f=1,nV
    do e=1,nV
      do b=1,nV
        do a=1,nV
          cW_vvvv(a,b,e,f) = cW_vvvv(a,b,e,f) - B_vvvv(b,a,e,f) + B_vvvv(a,b,e,f)
        end do
      end do
    end do
  end do
  deallocate(A_ovvv,B_vvvv)

  !do a=1,nV
  !  do b=1,nV
  !    do e=1,nV
  !      do f=1,nV
  !         
  !        do m=1,nO
  !          do n=1,nO
  !            cW_vvvv(a,b,e,f) = cW_vvvv(a,b,e,f) + 0.25d0*tau(m,n,a,b)*v_oovv(m,n,e,f)
  !          end do
  !        end do

  !      end do
  !    end do
  !  end do
  !end do
  call dgemm('T','N', nV*nV, nV*nV, nO*nO, &
             0.25d0, tau    , size(tau,1) * size(tau,2), &
                     v_oovv , size(v_oovv,1) * size(v_oovv,2), &
             1.d0  , cW_vvvv, size(cW_vvvv,1) * size(cW_vvvv,2))

end

! Kronecker

function Kronecker_delta(i,j) result(delta)

  implicit none

  BEGIN_DOC
  ! If i == j return 1 else returns 0
  END_DOC

  integer,intent(in)            :: i,j

  double precision              :: delta

  if(i == j) then
    delta = 1d0
  else
    delta = 0d0
  endif

end

! F_alpha

subroutine get_fock_matrix_alpha(det,F)
  
  implicit none
  
  BEGIN_DOC
  ! Returns the alpha Fock matrix in MO basis associated with the determinant given as input
  END_DOC
  ! in
  integer(bit_kind), intent(in) :: det(N_int,2)

  ! out
  double precision, intent(out) :: F(mo_num,mo_num)

  ! internal
  integer :: i,j,k

  F = Fock_matrix_mo_alpha

end

! F_beta

subroutine get_fock_matrix_beta(det,F)
  
  implicit none
  
  BEGIN_DOC
  ! Returns the beta Fock matrix in MO basis associated with the determinant given as input
  END_DOC
  
  integer(bit_kind), intent(in) :: det(N_int,2)
  
  double precision, intent(out) :: F(mo_num,mo_num)

  F = Fock_matrix_mo_beta

end

! n spin orb

subroutine extract_n_spin(n)

  implicit none

  BEGIN_DOC
  ! Returns the number of occupied alpha, occupied beta, virtual alpha, virtual beta spin orbitals
  END_DOC

  integer, intent(out) :: n(4)
  
  integer(bit_kind)    :: res(N_int,2)
  integer              :: i, si
  logical              :: ok

  n = 0
  
  do si = 1, 2
    do i = n_core_orb+1, mo_num
      call apply_hole(psi_det(:,:,1), si, i, res, ok, N_int)
      if (ok) then
        n(si) = n(si) + 1
      else
        n(si+2) = n(si+2) + 1
      endif
    enddo
  enddo

end

! List spin orb

subroutine extract_list_orb(nO_m,nV_m,list_occ,list_vir)

  implicit none

  BEGIN_DOC
  ! Returns the the list of occupied alpha/beta, virtual alpha/beta spin orbitals
  END_DOC
  
  integer, intent(in)  :: nO_m, nV_m
  
  integer, intent(out) :: list_occ(nO_m,2), list_vir(nV_m,2)
  
  integer(bit_kind)    :: res(N_int,2)
  integer              :: i, si, idx_o, idx_v, idx_i, idx_b
  logical              :: ok

  list_occ = 0
  list_vir = 0

  ! List of occ/vir alpha/beta

  ! occ alpha -> list_occ(:,1)
  ! occ beta -> list_occ(:,2)
  ! vir alpha -> list_vir(:,1)
  ! vir beta -> list_vir(:,2)
  do si = 1, 2
    idx_o = 1
    idx_v = 1
    do i = n_core_orb+1, mo_num
      call apply_hole(psi_det(:,:,1), si, i, res, ok, N_int)
      if (ok) then
        list_occ(idx_o,si) = i
        idx_o = idx_o + 1
      else
        list_vir(idx_v,si) = i
        idx_v = idx_v + 1
      endif
    enddo
  enddo

end

! idx shift

subroutine shift_idx(s,n_S,shift)

  implicit none

  BEGIN_DOC
  ! Shift for the partitionning alpha/beta of the spin orbitals
  END_DOC

  integer, intent(in)  :: s, n_S(2)
  integer, intent(out) :: shift

  if (s == 1) then
    shift = 0
  else
    shift = n_S(1)
  endif
  
end

! F

subroutine gen_f_ints(n1,n2, n1_S,n2_S, list1,list2, dim1,dim2, f)

  implicit none

  BEGIN_DOC
  ! Compute the Fock matrix corresponding to two lists of spin orbitals.
  ! Ex: occ/occ, occ/vir,...
  END_DOC

  integer, intent(in)           :: n1,n2, n1_S(2), n2_S(2)
  integer, intent(in)           :: list1(n1,2), list2(n2,2)
  integer, intent(in)           :: dim1, dim2
  
  double precision, intent(out) :: f(dim1, dim2)

  double precision, allocatable :: tmp_F(:,:)
  integer                       :: i,j, idx_i,idx_j,i_shift,j_shift
  integer                       :: tmp_i,tmp_j
  integer                       :: si,sj,s

  allocate(tmp_F(mo_num,mo_num))

  do sj = 1, 2
    call shift_idx(sj,n2_S,j_shift)
    do si = 1, 2
      call shift_idx(si,n1_S,i_shift)
      s = si + sj

      if (s == 2) then
        call get_fock_matrix_alpha(psi_det(:,:,1),tmp_F)
      elseif (s == 4) then
        call get_fock_matrix_beta (psi_det(:,:,1),tmp_F)
      else
        tmp_F = 0d0
      endif
      
      do tmp_j = 1, n2
        j = list2(tmp_j,sj)
        idx_j = tmp_j + j_shift
        do tmp_i = 1, n1
          i = list1(tmp_i,si)
          idx_i = tmp_i + i_shift
          f(idx_i,idx_j) = tmp_F(i,j)
        enddo
      enddo

    enddo
  enddo

  deallocate(tmp_F)
  
end

! V

subroutine gen_v_ints(n1,n2,n3,n4, n1_S,n2_S,n3_S,n4_S, list1,list2,list3,list4, dim1,dim2,dim3,dim4, v)

  implicit none

   BEGIN_DOC
  ! Compute the bi electronic integrals corresponding to four lists of spin orbitals.
  ! Ex: occ/occ/occ/occ, occ/vir/occ/vir, ...
  END_DOC

  integer, intent(in)           :: n1,n2,n3,n4,n1_S(2),n2_S(2),n3_S(2),n4_S(2)
  integer, intent(in)           :: list1(n1,2), list2(n2,2), list3(n3,2), list4(n4,2)
  integer, intent(in)           :: dim1, dim2, dim3, dim4
  double precision, intent(out) :: v(dim1,dim2,dim3,dim4)

  double precision              :: mo_two_e_integral
  integer                       :: i,j,k,l,idx_i,idx_j,idx_k,idx_l
  integer                       :: i_shift,j_shift,k_shift,l_shift
  integer                       :: tmp_i,tmp_j,tmp_k,tmp_l
  integer                       :: si,sj,sk,sl,s

  do sl = 1, 2
    call shift_idx(sl,n4_S,l_shift)
    do sk = 1, 2
      call shift_idx(sk,n3_S,k_shift)
      do sj = 1, 2
        call shift_idx(sj,n2_S,j_shift)
        do si = 1, 2
          call shift_idx(si,n1_S,i_shift)
    
          s = si+sj+sk+sl
           
          do tmp_l = 1, n4_S(sl)
            l = list4(tmp_l,sl)
            idx_l = tmp_l + l_shift
            do tmp_k = 1, n3_S(sk)
              k = list3(tmp_k,sk)
              idx_k = tmp_k + k_shift
              do tmp_j = 1, n2_S(sj)
                j = list2(tmp_j,sj)
                idx_j = tmp_j + j_shift
                do tmp_i = 1, n1_S(si)  
                  i = list1(tmp_i,si)
                  idx_i = tmp_i + i_shift
          
                  if (s == 4 .or. s == 8) then
                     v(idx_i,idx_j,idx_k,idx_l) = mo_two_e_integral(i,j,k,l) - mo_two_e_integral(i,j,l,k)
                  elseif (si == sk .and. sj == sl) then
                     v(idx_i,idx_j,idx_k,idx_l) = mo_two_e_integral(i,j,k,l)
                  elseif (si == sl .and. sj == sk) then
                     v(idx_i,idx_j,idx_k,idx_l) = - mo_two_e_integral(i,j,l,k)
                  else
                     v(idx_i,idx_j,idx_k,idx_l) = 0d0
                  endif

                enddo
              enddo
            enddo
          enddo
          
        enddo
      enddo
    enddo
  enddo
  
end
