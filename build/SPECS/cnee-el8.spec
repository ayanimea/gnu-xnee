%define packname        Xnee
%define cliname         cnee

Name:           %{cliname}
Version:        XNEE_VERSION
Release:        XNEE_RELEASE%{?dist}
Summary:        X11 event recorder, replayer and distributor (command line tool)

License:        GPL-2.0-or-later
URL:            https://www.gnu.org/software/xnee
Source0:        https://ftp.gnu.org/pub/gnu/xnee/%{packname}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool
BuildRequires:  pkgconfig
BuildRequires:  libX11-devel
BuildRequires:  libXtst-devel
BuildRequires:  texinfo

Requires:       libX11
Requires:       libXtst

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
%make_build
make -C cnee/src man

%install
%make_install

mkdir -p %{buildroot}%{_datadir}/xnee/projects
install -m 644 projects/*.xnp %{buildroot}%{_datadir}/xnee/projects/

%files
%doc AUTHORS COPYING ChangeLog INSTALL NEWS README TODO EXAMPLES FAQ BUGS
%{_bindir}/cnee
%{_mandir}/man1/cnee.1*
%{_mandir}/man1/xnee.1*
%{_datadir}/xnee/
%{_datadir}/pixmaps/xnee.xpm
%{_datadir}/pixmaps/xnee.png
%exclude %{_libdir}/libtestcb.*

%changelog
# end of file
