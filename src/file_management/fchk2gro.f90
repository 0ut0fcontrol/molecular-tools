program fchk2gro


    !==============================================================
    ! This code uses of MOLECULAR_TOOLS (version 1.0/March 2012)
    !==============================================================
    !
    ! Description:
    ! -----------
    ! Forms a gro structure with the one present in the fchk
    !
    !
    !============================================================================    

    !*****************
    !   MODULE LOAD
    !*****************
    !============================================
    !   Generic
    !============================================
    use alerts
    use line_preprocess
    use constants 
    use verbosity
    use matrix
    use matrix_print
    !============================================
    !   Structure types module
    !============================================
    use structure_types
    !============================================
    !   File readers
    !============================================
    use generic_io
    use generic_io_molec
    use xyz_manage
    use gaussian_manage
    !============================================
    !  Structure-related modules
    !============================================
    use molecular_structure
    use ff_build

    implicit none

    !====================== 
    !System variables
    type(str_resmol) :: molec, &
                        molec_aux
    !====================== 

    !=============
    !Counters and dummies
    integer :: i,j,k,l, jj,kk, iat
    character(len=1) :: null
    logical :: overwrite    = .false. ,&
               make_connect = .false. ,&
               use_elements = .false. ,&
               remove_com   = .false.
    !Swap related counters
    integer :: iat_new, iat_orig, nswap
    !=============

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10, &
               I_SWP=11, &
               O_OUT=20  
    !files
    character(len=5)   :: resname="read"
    character(len=200) :: title="read"
    character(len=10) :: filetype_inp="guess",&
                         filetype_out="guess"
    character(len=200):: inpfile="input.fchk",&
                         addfile="none",      &
                         outfile="default"   ,&
                         swapfile="none"  
    !status
    integer :: IOstatus
    character(len=7) :: stat="new" !do not overwrite when writting
    !===================


    ! 0. GET COMMAND LINE ARGUMENTS
    call parse_input(inpfile,filetype_inp,outfile,filetype_out,addfile,overwrite,make_connect,&
                     use_elements,remove_com,resname,swapfile,title)

 
    ! 1. READ INPUT
    ! ---------------------------------
    ! Manage special files (fcc)
    if (adjustl(filetype_inp) == "fcc".and.adjustl(addfile) == "none") then
        call alert_msg("fatal","For fcc filetype, indicate statefile as -f and fcc-input as -add")
    endif
    if (adjustl(filetype_inp) == "fcc") then
        ! inpfile has Nat, Nvib, and Masses          <= in addfile
        ! statefile has coordinates and normal modes <= in inpfile
        ! Generic readers parse the state (not the inpfile)
        ! so we get that info here before calling the parser
        open(I_INP,file=addfile,status='old',iostat=IOstatus)
        if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(addfile)) )
        read(I_INP,*,iostat=IOstatus) molec%natoms
        if (IOstatus /= 0) &
          call alert_msg("fatal","when scanning -add file. Make sure to indicate statefile as -f and fcc-input as -add")
        read(I_INP,*,iostat=IOstatus) k ! Nvib
        if (IOstatus /= 0) &
          call alert_msg("fatal","when scanning -add file. Make sure to indicate statefile as -f and fcc-input as -add")
        do i=1,molec%natoms 
            read(I_INP,*,iostat=IOstatus) molec%atom(i)%mass
            if (IOstatus /= 0) &
              call alert_msg("fatal","when scanning -add file. Make sure to indicate statefile as -f and fcc-input as -add")
            !Set atomnames from atommasses
            call atominfo_from_atmass(molec%atom(i)%mass,  &
                                      molec%atom(i)%AtNum, &
                                      molec%atom(i)%name)
        enddo
        close(I_INP)
    endif

    open(I_INP,file=inpfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )

    if (adjustl(filetype_inp) == "guess") call split_line_back(inpfile,".",null,filetype_inp)
    call generic_strmol_reader(I_INP,filetype_inp,molec)
    close(I_INP)
    !Option to specify the resname from command line
    if (adjustl(resname) /= "read") molec%atom(:)%resname=resname

    ! 2. MAKE CHANGES IF REQUIRED
    ! -------------------------------
    !Swaping atoms
    if (adjustl(swapfile) /= "none") then
        open(I_SWP,file=swapfile,status='old',iostat=IOstatus)
        if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(swapfile)) )
        read(I_SWP,*) nswap
        molec_aux = molec
        do i=1,nswap
            read(I_SWP,*) iat_orig, iat_new
            molec_aux%atom(iat_new)=molec%atom(iat_orig)
        enddo
        molec = molec_aux
        close(I_SWP)
    endif
    !Forcing element names (no FF labels)
    if (use_elements) molec%atom(:)%name = molec%atom(:)%element
    !Removing center of gravity
    if (remove_com) then
        call atname2element(molec)
        call assign_masses_molec(molec)
        call get_com(molec)
        i=molec%natoms
        molec%atom(1:i)%x = molec%atom(1:i)%x - molec%comX
        molec%atom(1:i)%y = molec%atom(1:i)%y - molec%comY
        molec%atom(1:i)%z = molec%atom(1:i)%z - molec%comZ
    endif

    ! 3. WRITE OUTPUT
    ! ---------------------------------
    if (overwrite) stat="unknown"
    open(O_OUT,file=outfile,status=stat,iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Cannot write in "//trim(adjustl(outfile))//&
                                                            ". Already exists? Use -ow to overwrite" )

    if (adjustl(filetype_out) == "guess") call split_line_back(outfile,".",null,filetype_out)
    !If PDB check if connections are requested
    if (make_connect .and. adjustl(filetype_out)=="pdb") then
        call guess_connect(molec)
        filetype_out="pdb-c"
    endif
    if (adjustl(title) /= "read") molec%title = trim(adjustl(title))
    call generic_strmol_writer(O_OUT,filetype_out,molec)
    close(O_OUT)

    stop


    !==============================================
    contains
    !=============================================

    subroutine parse_input(inpfile,filetype_inp,outfile,filetype_out,addfile,overwrite,make_connect,&
                           use_elements,remove_com,resname,swapfile,title)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile,outfile,addfile,&
                                          filetype_inp,filetype_out, &
                                          resname,swapfile,title
        logical,intent(inout) :: overwrite, make_connect, use_elements, &
                                 remove_com
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
                case ("-fti") 
                    call getarg(i+1, filetype_inp)
                    argument_retrieved=.true.

                case ("-add") 
                    call getarg(i+1,addfile)
                    argument_retrieved=.true.

                case ("-o") 
                    call getarg(i+1, outfile)
                    argument_retrieved=.true.
                case ("-fto") 
                    call getarg(i+1, filetype_out)
                    argument_retrieved=.true.

                case ("-r")
                    overwrite=.true.

                case ("-ow")
                    overwrite=.true.

                case ("-rn")
                    call getarg(i+1, resname)
                    argument_retrieved=.true.

                case ("-connect")
                    make_connect=.true.

                case ("-use-elems")
                    use_elements=.true.

                case ("-rmcom")
                    remove_com=.true.

                case ("-swap")
                    call getarg(i+1, swapfile)
                    argument_retrieved=.true.

                case ("-title")
                    call getarg(i+1, title)
                    argument_retrieved=.true.
        
                case ("-h")
                    need_help=.true.

                case default
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

        !The default output is now xyz
        if (adjustl(outfile) == "default") then
            call split_line_back(inpfile,".",outfile,null)
            outfile=trim(adjustl(outfile))//".xyz"
        endif

        ! Some checks on the input
        !----------------------------
        !Print options (to stderr)
        write(0,'(/,A)') '========================================================'
        write(0,'(/,A)') '        F O R M A T    C O N V E R T E R '    
        write(0,'(/,A)') '        Convert between geometry formats '      
        call print_version()
        write(0,'(/,A)') '========================================================'
        write(0,'(/,A)') '-------------------------------------------------------------------'
        write(0,'(A)')   ' Flag         Description                      Value'
        write(0,'(A)')   '-------------------------------------------------------------------'
        write(0,*)       '-f           Input structure file             ', trim(adjustl(inpfile))
        write(0,*)       '-fti         \_ FileTyep                      ', trim(adjustl(filetype_inp))
        write(0,*)       '-add         Additional file (fcc: inputfile) ', trim(adjustl(addfile))
        write(0,*)       '-o           Output structure file            ', trim(adjustl(outfile))
        write(0,*)       '-fto         \_ FileTyep                      ', trim(adjustl(filetype_out))
        write(0,*)       '-ow          Overwrite output if exists       ',  overwrite
        write(0,*)       '-swap        File with reordering instruction ',  trim(adjustl(swapfile))
        write(0,*)       '-rn          Residue name                     ',  trim(adjustl(resname))
        write(0,*)       '-connect     Add connectivity (pdb files)     ',  make_connect
        write(0,*)       '-use-elems   Use elements not FF names        ',  use_elements
        write(0,*)       '-rmcom       Remove COM (translate)           ',  remove_com
        write(0,*)       '-title       Title/header of the file         ', trim(adjustl(title))
        write(0,*)       '-h           This help                       ',  need_help
        write(0,*)       '-------------------------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input


end program fchk2gro
