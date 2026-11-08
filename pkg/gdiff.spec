Name:           gdiff
Version:        1.3.0
Release:        1%{?dist}
Summary:        CLI tool to copy git staged diffs and a rule file to the clipboard

License:        MIT
URL:            https://github.com/0Crazy-0/gdiff
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildArch:      noarch
Requires:       bash
Requires:       git
Recommends:     wl-clipboard

%description
gdiff is an ultra-lightweight, 100% local, and free CLI tool that gathers
the staged git diff, appends a customizable instructions/rule file, and
copies the combined output to your system clipboard, so you can paste it
into any LLM chat UI to get a perfect conventional commit message.

%prep
%autosetup

%build
# Nothing to build: gdiff is a pure shell script

%install
install -Dm755 bash/gdiff     %{buildroot}%{_bindir}/gdiff
install -Dm644 share/rule.txt %{buildroot}%{_datadir}/gdiff/rule.txt

%files
%license LICENSE
%doc README.md
%{_bindir}/gdiff
%{_datadir}/gdiff/

%changelog
* Sat Nov 7 2026 crazy <0crazy.dev@gmail.com> - 1.3.0-1
- Add --commit / -c option to diff existing commits by position, hash or ref
- Add --message / -m and --info options to print commit messages
- Fix commit position lookup to count all commits following git log order

* Sat Sep 5 2026 crazy <0crazy.dev@gmail.com> - 1.2.0-1
- Add Windows config path support (APPDATA, GDIFF_CONFIG_HOME)
- Add PowerShell port and universal install script

* Sat Sep  5 2026 crazy <0crazy.dev@gmail.com> - 1.1.0-1
- Initial RPM packaging for Fedora
- Ship bash script and rule file (noarch)
