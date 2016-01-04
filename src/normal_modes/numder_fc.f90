program numder_fc


    !==============================================================
    ! This code uses of MOLECULAR_TOOLS (version 1.0/March 2012)
    !==============================================================
    !
    ! Description:
    ! -----------
    ! Program to compute the numerical freqs from G09 scan
    !
    ! Compilation instructions (for mymake script):
    !
    ! Change log:
    !
    ! TODO:
    ! ------
    !
    ! History

    !
    !============================================================================    

!*****************
!   MODULE LOAD
!*****************
!============================================
!   Generic (structure_types independent)
!============================================
    use alerts
    use line_preprocess
    use gaussian_manage
    use constants

    implicit none


    real(8),dimension(100) :: R
    real(8),dimension(100) :: E
    real(8) :: derA, derB, dder, freq, delta, der

    character(len=200) :: line, dummy_char
    character(len=13)  :: marker
    character(len=3)   :: density="SCF"
    logical            :: td_calc=.false.

    integer :: i,j, iread, IOstatus

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10
    !files
    character(len=200):: inpfile ="input.log"

! (End of variables declaration) 
!==================================================================================

    ! 0. GET COMMAND LINE ARGUMENTS
    call parse_input(inpfile,td_calc)

    if (.not.td_calc) then
        marker="SCF Done:  E("
    else
        marker="E(TD-HF/TD-KS"
    endif

    open(I_INP,file=inpfile,status="old")

    i=1
    iread=0
    IOstatus=0
    do while ( IOstatus == 0 )
        read(I_INP,'(X,A)',IOSTAT=IOstatus) line
        if (IOstatus /= 0) exit
        if ( INDEX(line,marker) /= 0 ) then
            call split_line(line,'=',dummy_char,line)
            read(line,*) E(i)
            ! The go to summary and read the title
            call summary_parser(I_INP,3,line)
            call split_line(line,'=',dummy_char,line)
            read(line,*) R(i)
            print*, R(i), E(i)
            i=i+1
            iread=1
        endif
    enddo
    if (i-1/=5) call alert_msg("fatal","logfile has not the the required number of steps."//&
                                       " Was it generated by nm_internal or nm_cartesian?") 

    !Scan is made in reverse order. Reorder points
!     aux_vec = R
!     j=5
!     do i=1,5
!         R(i) = aux_vec(j)
!         j=j-1
!     enddo
!     aux_vec = E
!     j=5
!     do i=1,5
!         E(i) = aux_vec(j)
!         j=j-1
!     enddo

    print*, ""
    print*, " Disp(a.u.)      der+(a.u.)      der-(a.u.)       FC(a.u.)       Freq(cm-1)"
    print*, "================================================================================="

    !Computation taking computing the first ders at points 2 and 4
    delta = R(3)-R(1)
    derA = (E(3)-E(1))/delta
    derB = (E(5)-E(3))/delta
    dder = (derB-derA)/delta
    freq = sign(dsqrt(abs(dder)*HARTtoJ/BOHRtoM**2/AUtoKG)/2.d0/pi/clight/1.d2,&
                         dder)
    print'(X,G11.4,3X,2G16.7,F16.7,3X,F10.3)', abs(delta)/2.d0, derA, derB, dder, freq

    !Computation taking computing the first ders at points half-way(2-3) and halfway (3-4)
    delta = R(2)-R(1)
    derA = (E(3)-E(2))/delta
    derB = (E(4)-E(3))/delta
    dder = (derB-derA)/delta
    freq = sign(dsqrt(abs(dder)*HARTtoJ/BOHRtoM**2/AUtoKG)/2.d0/pi/clight/1.d2,&
                         dder)
    print'(X,G11.4,3X,2G16.7,F16.7,3X,F10.3)', abs(delta)/2.d0, derA, derB, dder, freq

    print*, ""

    print*, ""
    print*, " Disp(a.u.)      der(a.u.)"
    print*, "================================================"
    !Taking large delta (in the middle: point 3)
    delta = R(5)-R(1)
    derA = (E(5)-E(1))/delta
    print'(X,G11.4,3X,E16.7,3X,F10.3)', abs(delta)/2.d0, derA
    !Taking small delta (in the middle: point 3)
    delta = R(4)-R(2)
    derA = (E(4)-E(2))/delta
    print'(X,G11.4,3X,E16.7,3X,F10.3)', abs(delta)/2.d0, derA

    print*, ""

    stop


    !==============================================
    contains
    !=============================================

    subroutine parse_input(inpfile,td_calc)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile
        logical,intent(inout)          :: td_calc
        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg

        argument_retrieved=.false.
        do i=1,iargc()
            if (argument_retrieved) then
                argument_retrieved=.false.
                cycle
            endif
            call getarg(i, arg) 
            select case (adjustl(arg))
                case ("-f") 
                    call getarg(i+1, inpfile)
                    argument_retrieved=.true.

                case ("-td") 
                    td_calc=.true.
        
                case ("-h")
                    need_help=.true.

                case default
                    print*, "Unkown command line argument: "//adjustl(arg)
                    stop
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

       !Print options (to stderr)
        write(0,'(/,A)') '--------------------------------------------------'
        write(0,'(/,A)') '          NUM DERIVATIVES FROM G09log FILE '          
        write(0,'(/,A)') '--------------------------------------------------'
        write(0,*) '-f              ', trim(adjustl(inpfile))
        write(0,*) '-td            ',  td_calc
        write(0,*) '-h             ',  need_help
        write(0,*) '--------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input
       

end program numder_fc

