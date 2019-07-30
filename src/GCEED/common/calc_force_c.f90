!
!  Copyright 2019 SALMON developers
!
!  Licensed under the Apache License, Version 2.0 (the "License");
!  you may not use this file except in compliance with the License.
!  You may obtain a copy of the License at
!
!      http://www.apache.org/licenses/LICENSE-2.0
!
!  Unless required by applicable law or agreed to in writing, software
!  distributed under the License is distributed on an "AS IS" BASIS,
!  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
!  See the License for the specific language governing permissions and
!  limitations under the License.
!
subroutine calc_force_c(mg,srg,tzpsi)
use salmon_parallel, only: nproc_group_korbital, nproc_group_global
use salmon_communication, only: comm_summation
use structures
use scf_data
use allocate_mat_sub
use read_pslfile_sub
use new_world_sub
implicit none
type(s_rgrid),intent(in) :: mg
type(s_sendrecv_grid),intent(inout) :: srg
complex(8) :: tzpsi(mg%is_overlap(1):mg%ie_overlap(1) &
&                  ,mg%is_overlap(2):mg%ie_overlap(2) &
&                  ,mg%is_overlap(3):mg%ie_overlap(3), 1:iobnum, k_sta:k_end)
integer :: ix,iy,iz,iob,ikoa,jj,j2,iatom,ia,ib,lm,ikoa2,iik
real(8) :: rbox1,rbox2
complex(8) :: cbox1
complex(8),allocatable :: uVpsibox(:,:,:,:),uVpsibox2(:,:,:,:)
real(8) :: rforce1(3,MI),rforce2(3,MI),rforce3(3,MI),rforce41(3,MI),rforce42(3,MI)
real(8) :: rab
integer :: iix,iiy,iiz

do iatom=1,MI
do j2=1,3
  rforce(j2,iatom)=0.d0
  rforce1(j2,iatom)=0.d0
  rforce2(j2,iatom)=0.d0
  rforce3(j2,iatom)=0.d0
  rforce41(j2,iatom)=0.d0
end do
end do

! ion-ion
do ia=1,MI
  ikoa=Kion(ia)
  do ib=1,MI
    if(ia/=ib)then
      ikoa2=Kion(ib)
      rab=sqrt((Rion(1,ia)-Rion(1,ib))**2+   &
               (Rion(2,ia)-Rion(2,ib))**2+   &
               (Rion(3,ia)-Rion(3,ib))**2)
      do j2=1,3
        rforce(j2,ia)=rforce(j2,ia)+Zps(ikoa)*Zps(ikoa2)*(Rion(j2,ia)-Rion(j2,ib))/rab**3
        rforce1(j2,ia)=rforce1(j2,ia)+Zps(ikoa)*Zps(ikoa2)*(Rion(j2,ia)-Rion(j2,ib))/rab**3
      end do
    end if
  end do
end do

call calc_gradient_fast_c(mg,srg,tzpsi,cgrad_wk)

! local part of force
do iatom=1,MI
do j2=1,3
  rbox1=0.d0
  do iik=k_sta,k_end
  do iob=1,iobnum
    do iz=mg%is(3),mg%ie(3)
    do iy=mg%is(2),mg%ie(2)
    do ix=mg%is(1),mg%ie(1)
      rbox1=rbox1-2.d0*rocc(iob,iik)*dble(conjg(cgrad_wk(ix,iy,iz,iob,iik,j2))*Vpsl_atom(ix,iy,iz,iatom)*tzpsi(ix,iy,iz,iob,iik))
    end do
    end do
    end do
  end do
  end do
  call comm_summation(rbox1,rbox2,nproc_group_global)
  rforce(j2,iatom)=rforce(j2,iatom)+rbox2*Hvol
  rforce2(j2,iatom)=rbox2*Hvol
end do
end do

! nonlocal part of force

allocate (uVpsibox(1:iobnum,k_sta:k_end,1:maxlm,1:MI))
allocate (uVpsibox2(1:iobnum,k_sta:k_end,1:maxlm,1:MI))

do iatom=1,MI
  do lm=1,maxlm
    do iik=k_sta,k_end
    do iob=1,iobnum
      uVpsibox(iob,iik,lm,iatom)=0.d0
    end do
    end do
  end do
end do

do iatom=1,MI
  ikoa=Kion(iatom)
  do iik=k_sta,k_end
  do iob=1,iobnum
    loop_lm2 : do lm=1,maxlm
      if ( abs(uVu(lm,iatom))<1.d-5 ) cycle loop_lm2
      cbox1=0.d0
!$OMP parallel do reduction( + : cbox1 )
      do jj=1,Mps(iatom)
        cbox1=cbox1+uV_all(jj,lm,iatom)*  &
                      tzpsi(Jxyz(1,jj,iatom),Jxyz(2,jj,iatom),Jxyz(3,jj,iatom),iob,iik)
      end do
      uVpsibox(iob,iik,lm,iatom)=cbox1*Hvol/uVu(lm,iatom)
    end do loop_lm2
  end do
  end do
end do

call comm_summation(uVpsibox,uVpsibox2,iobnum*k_num*maxlm*MI,nproc_group_korbital)

do iatom=1,MI
  ikoa=Kion(iatom)
  do j2=1,3
    rbox1=0.d0
    do iik=k_sta,k_end
    do iob=1,iobnum
      do jj=1,Mps(iatom)
        do lm=1,maxlm
          rbox1=rbox1-2.d0*rocc(iob,iik)*dble(uV(jj,lm,iatom)*   &
                  conjg(cgrad_wk(Jxyz(1,jj,iatom),Jxyz(2,jj,iatom),  &
                                 Jxyz(3,jj,iatom),iob,iik,j2))* &
                  uVpsibox2(iob,iik,lm,iatom))
        end do
      end do
    end do
    end do
    call comm_summation(rbox1,rbox2,nproc_group_global)
    rforce(j2,iatom)=rforce(j2,iatom)+rbox2*Hvol
    rforce3(j2,iatom)=rbox2*Hvol
  end do
end do

select case(ikind_eext)
  case(1,2,4,6:8,13,14,15)
  do iatom=1,MI
    ikoa=Kion(iatom)
    iix=nint(Rion(1,iatom)/Hgs(1)-1.0d0)
    iiy=nint(Rion(2,iatom)/Hgs(2)-1.0d0)
    iiz=nint(Rion(3,iatom)/Hgs(3)-1.0d0)
    if(iix>=ng_sta(1).and.iix<=ng_end(1).and.   &
       iiy>=ng_sta(2).and.iiy<=ng_end(2).and.   &
       iiz>=ng_sta(3).and.iiz<=ng_end(3)) then
      rforce41(1,iatom)=rforce41(1,iatom)+                               &
          Zps(ikoa)*(bN1/Hgs(1)*(Vbox(iix+1,iiy,iiz)-Vbox(iix-1,iiy,iiz))      &
                 + bN2/Hgs(1)*(Vbox(iix+2,iiy,iiz)-Vbox(iix-2,iiy,iiz))      &
                 + bN3/Hgs(1)*(Vbox(iix+3,iiy,iiz)-Vbox(iix-3,iiy,iiz))      &
                 + bN4/Hgs(1)*(Vbox(iix+4,iiy,iiz)-Vbox(iix-4,iiy,iiz)))
      rforce41(2,iatom)=rforce41(2,iatom)+                               &
          Zps(ikoa)*(bN1/Hgs(2)*(Vbox(iix,iiy+1,iiz)-Vbox(iix,iiy-1,iiz))      &
                 + bN2/Hgs(2)*(Vbox(iix,iiy+2,iiz)-Vbox(iix,iiy-2,iiz))      &
                 + bN3/Hgs(2)*(Vbox(iix,iiy+3,iiz)-Vbox(iix,iiy-3,iiz))      &
                 + bN4/Hgs(2)*(Vbox(iix,iiy+4,iiz)-Vbox(iix,iiy-4,iiz)))
      rforce41(3,iatom)=rforce41(3,iatom)+                               &
          Zps(ikoa)*(bN1/Hgs(3)*(Vbox(iix,iiy,iiz+1)-Vbox(iix,iiy,iiz-1))      &
                 + bN2/Hgs(3)*(Vbox(iix,iiy,iiz+2)-Vbox(iix,iiy,iiz-2))      &
                 + bN3/Hgs(3)*(Vbox(iix,iiy,iiz+3)-Vbox(iix,iiy,iiz-3))      &
                 + bN4/Hgs(3)*(Vbox(iix,iiy,iiz+4)-Vbox(iix,iiy,iiz-4)))
    end if
  end do
  call comm_summation(rforce41,rforce42,3*MI,nproc_group_global)
  do iatom=1,MI
    rforce(1:3,iatom)=rforce(1:3,iatom)+rforce42(1:3,iatom)
  end do
end select

deallocate(uVpsibox,uVpsibox2)

end subroutine calc_force_c
