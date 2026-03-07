%define packname        Xnee
%define cliname         cnee

Name:           %{cliname}
Version:        XNEE_VERSION
Release:        XNEE_RELEASE%{?dist}
Summary:        X11 event recorder, replayer and distributor (command line tool)

# NOTE: The COPYING file in this package contains the GNU General Public
# License version 3 (GPLv3). The License tag below reflects the original
# upstream project packaging convention and has not been updated to GPLv3+
# to avoid unintended changes to distributed package metadata.
License:        GPLv2+
URL:            https://www.gnu.org/software/xnee
Source0:        https://ftp.gnu.org/pub/gnu/xnee/%{packname}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool
BuildRequires:  pkgconfig
BuildRequires:  libX11-devel%{?_isa}
BuildRequires:  libXtst-devel%{?_isa}
BuildRequires:  texinfo

Requires:       libX11%{?_isa}
Requires:       libXtst%{?_isa}

%description
GNU Xnee is a suite of programs that can record, replay and distribute
user actions under the X11 environment. Think of it as a macro recorder
for X11.

This package contains the command line tool cnee, which allows scripting
and automation of X11 input event recording and replaying.

%prep
%setup -q -n %{packname}-%{version}

%build
make -f Makefile.cvs generate
%configure \
    --disable-gui \
    --disable-doc \
    --disable-xinput2
make %{?_smp_mflags}
make -C cnee/src man

%install
make install DESTDIR=%{buildroot}

mkdir -p %{buildroot}%{_datadir}/xnee/projects
install -m 644 projects/*.xnp %{buildroot}%{_datadir}/xnee/projects/

%files
%doc COPYING AUTHORS ChangeLog INSTALL NEWS README TODO EXAMPLES FAQ BUGS
%{_bindir}/cnee
%{_mandir}/man1/cnee.1*
%{_mandir}/man1/xnee.1*
%{_datadir}/xnee/
%{_datadir}/pixmaps/xnee.xpm
%{_datadir}/pixmaps/xnee.png
%exclude %{_libdir}/libtestcb.*

%changelog
# end of file
