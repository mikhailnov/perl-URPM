%define name perl-URPM
%define real_name URPM
%define version 0.08
%define release 4mdk

%{expand:%%define rpm_version %(rpm -q --queryformat '%{VERSION}-%{RELEASE}' rpm)}

Packager:       Fran�ois Pons <fpons@mandrakesoft.com>
Summary:	URPM module for perl
Name:		%{name}
Version:	%{version}
Release:	%{release}
License:	GPL or Artistic
Group:		Development/Perl
Distribution:	Mandrake Linux
Source:		%{real_name}-%{version}.tar.bz2
Prefix:		%{_prefix}
BuildRequires:	perl-devel rpm-devel >= 4.0.3 bzip2-devel gcc
Requires:	perl, rpm >= %{rpm_version}, bzip2 >= 1.0
BuildRoot:	%{_tmppath}/%{name}-buildroot

%description
The URPM module allows you to manipulate rpm files, rpm header files and
hdlist files and manage them in memory.

%prep
%setup -q -n %{real_name}-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor PREFIX=%{prefix}
make OPTIMIZE="$RPM_OPT_FLAGS" PREFIX=%{prefix}
make test

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall PREFIX=$RPM_BUILD_ROOT%{prefix}

%clean 
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc README
#%{_mandir}/man3pm/*
%{perl_vendorarch}/URPM.pm
%{perl_vendorarch}/URPM
%{perl_vendorarch}/auto/URPM


%changelog
* Tue Jul  9 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.08-4mdk
- fixed too many opened files when building hdlist.

* Tue Jul  9 2002 Pixel <pixel@mandrakesoft.com> 0.08-3mdk
- rebuild for perl 5.8.0

* Mon Jul  8 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.08-2mdk
- fixed rflags setting (now keep more than one element).
- fixed setting of ask_unselect correctly.

* Mon Jul  8 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.08-1mdk
- added transaction flags (equivalence to --force and --ignoreSize).
- simplified some transaction method names.
- added script fd support.

* Fri Jul  5 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.07-2mdk
- fixed transaction methods so that install works.

* Thu Jul  4 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.07-1mdk
- added transaction methods and URPM::Transaction type (for DrakX).
- obsoleted URPM::DB::open_rw and removed it.

* Wed Jul  3 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.06-2mdk
- fixed virtual provides obsoleted by other package (means kernel
  is requested to be installed even if other kernel is installed).

* Wed Jul  3 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.06-1mdk
- added header_filename and update_header to URPM::Package.
- added virtual flag selected to URPM::Package.
- added rate and rflags tags to URPM::Package.
- added URPM::DB::rebuild.
- fixed build of hdlist with non standard rpm filename.

* Mon Jul  1 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.05-2mdk
- fixed selection of obsoleted package already installed but
  present in depslist.

* Fri Jun 28 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.05-1mdk
- fixed ask_remove not to contains arch.
- removed relocate_depslist (obsoleted).

* Wed Jun 26 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.04-6mdk
- fixed work around of rpmlib where provides should be at
  left position of rpmRangesOverlap.

* Tue Jun 18 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.04-5mdk
- fixed wrong range overlap evaluation (libgcc >= 3.1 and libgcc.so.1).

* Thu Jun 13 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.04-4mdk
- fixed too many package selected on --auto-select.

* Thu Jun 13 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.04-3mdk
- fixed compare_pkg (invalid arch comparisons sometimes).
- added (still unused) obsolete flag.

* Thu Jun 13 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.04-2mdk
- added ranges_overlap method (uses rpmRangesOverlap in rpmlib).
- made Resolve module to be operational (and usable).

* Tue Jun 11 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.04-1mdk
- added Resolve.pm file.

* Thu Jun  6 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.03-2mdk
- fixed incomplete compare_pkg not taking into account score
  of arch.

* Thu Jun  6 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.03-1mdk
- added more flag method to URPM::Package
- avoid garbage output when reading hdlist archive.
- moved id internal reference to bit field of flag.

* Wed Jun  5 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.02-3mdk
- removed log on opening/closing rpmdb.
- modified reading of archive to avoid incomplete read.

* Wed Jun  5 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.02-2mdk
- added log on opening/closing rpmdb.

* Mon Jun  3 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.02-1mdk
- new version with extended parameters list for URPM::Build.
- fixed code to be -w clean.

* Fri May 31 2002 Fran�ois Pons <fpons@mandrakesoft.com> 0.01-1mdk
- initial revision.
