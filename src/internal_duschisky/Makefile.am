AUTOMAKE_OPTIONS = subdir-objects

bin_PROGRAMS = internal_duschinsky zmat2modredundant vertical2adiabatic

vertical2adiabatic_SOURCES = ../modules/alerts.f90\
                      ../modules/line_preprocess.f90\
                      ../modules/constants_mod.f90\
                      ../modules/matrix.f90\
                      ../modules/MatrixMod.f90\
                      ../modules/matrix_print.f90\
                      ../modules/structure_types_v4.f90\
                      ../modules/gro_manage_v4.f90\
                      ../modules/pdb_manage_v4.f90\
                      ../modules/gaussian_manage_v4.f90\
                      ../modules/gaussian_fchk_manage_v4.f90\
                      ../modules/xyz_manage_v4.f90\
                      ../modules/molcas_unsym_manage_v4.f90\
                      ../modules/molecular_structure.f90\
                      ../modules/ff_build_module_v4.f90\
                      ../modules/atomic_geom_v2.f90\
                      ../modules/symmetry_mod_v4.f90\
                      ../modules/internal_SR9_v4_NvibAdd.f90\
                      ../modules/zmat_manage_v4.f90\
                      vertical2adiabatic.f90
vertical2adiabatic_LDFLAGS = @LIBS@
# This enforces to recompile all modules (like that we avoid conflicting with internal_SR9_v4
# RECOMPILE is only a dummy flag
vertical2adiabatic_FCFLAGS = -DRECOMPILE

internal_duschinsky_SOURCES = ../modules/alerts.f90\
                      ../modules/line_preprocess.f90\
                      ../modules/constants_mod.f90\
                      ../modules/matrix.f90\
                      ../modules/MatrixMod.f90\
                      ../modules/matrix_print.f90\
                      ../modules/structure_types_v4.f90\
                      ../modules/gro_manage_v4.f90\
                      ../modules/pdb_manage_v4.f90\
                      ../modules/gaussian_manage_v4.f90\
                      ../modules/gaussian_fchk_manage_v4.f90\
                      ../modules/xyz_manage_v4.f90\
                      ../modules/molcas_unsym_manage_v4.f90\
                      ../modules/molecular_structure.f90\
                      ../modules/ff_build_module_v4.f90\
                      ../modules/atomic_geom_v2.f90\
                      ../modules/symmetry_mod_v4.f90\
                      ../modules/internal_SR9_v4_NvibAdd.f90\
                      ../modules/zmat_manage_v4.f90\
                      internal_duschinski_v13_v4.f90
internal_duschinsky_LDFLAGS = @LIBS@
# This enforces to recompile all modules (like that we avoid conflicting with internal_SR9_v4
# RECOMPILE is only a dummy flag
internal_duschinsky_FCFLAGS = -DRECOMPILE


zmat2modredundant_SOURCES = ../modules/alerts.f90\
                      ../modules/line_preprocess.f90\
                      ../modules/constants_mod.f90\
                      ../modules/matrix.f90\
                      ../modules/MatrixMod.f90\
                      ../modules/matrix_print.f90\
                      ../modules/structure_types_v4.f90\
                      ../modules/gro_manage_v4.f90\
                      ../modules/pdb_manage_v4.f90\
                      ../modules/gaussian_manage_v4.f90\
                      ../modules/gaussian_fchk_manage_v4.f90\
                      ../modules/xyz_manage_v4.f90\
                      ../modules/molcas_unsym_manage_v4.f90\
                      ../modules/molecular_structure.f90\
                      ../modules/ff_build_module_v4.f90\
                      ../modules/atomic_geom_v2.f90\
                      ../modules/symmetry_mod_v4.f90\
                      ../modules/internal_SR9_v4_NvibAdd.f90\
                      ../modules/zmat_manage_v4.f90\
                      zmat2modredundant.f90
zmat2modredundant_LDFLAGS = @LIBS@

CLEANFILES =*.mod 

#                       ../modules/internal_SR9_v4.f90