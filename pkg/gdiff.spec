Name:           gdiff
Version:        1.1.0
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
* Sat Sep  5 2026 Axel Vasquez <axelvasquez582@gmail.com> - 1.1.0-1
- Initial RPM packaging for Fedora
- Ship bash script and rule file (noarch)
