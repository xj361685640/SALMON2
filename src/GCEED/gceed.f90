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
subroutine gceed
  use plusU_global, only: read_Hubbard_parameters
  implicit none
  character(30) :: cfunction2

  call read_input_gceed(cfunction2)
  call read_Hubbard_parameters

  if(cfunction2=="GS")then
    call real_space_dft
  else if(cfunction2=="BAND")then
    call real_space_band
  else if(cfunction2=="RT")then
    call real_time_dft
  end if

end subroutine gceed