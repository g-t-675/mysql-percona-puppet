# percona_version.rb

Facter.add("perconaversion") do
	setcode do
		Facter::Util::Resolution.exec('/usr/bin/dpkg-query -W -f=\'${Version}\' percona-xtradb-cluster-common-5.5 2>/dev/null')
	end
end
