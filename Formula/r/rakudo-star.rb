class RakudoStar < Formula
  desc "Rakudo compiler and commonly used packages"
  homepage "https://rakudo.org/"
  url "https://github.com/rakudo/star/releases/download/2025.01/rakudo-star-2025.01.tar.gz"
  sha256 "34c2853614c6a5b830fc7efccfde3281960a815023e6fac6835643bf8ae9f779"
  license "Artistic-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 arm64_sequoia: "aec110488a4c209dc1d209e721a3059f0e8b22dd6b60fe047bf42ce67649583f"
    sha256 arm64_sonoma:  "1a9a5050c1f9729cb5c844dee4248b2b4200f98f5d77e8e535202ea591b03b00"
    sha256 arm64_ventura: "981a9d4e4ba89f003666967301aa42cd22595cadfcccffc55f79e6f5cf8fd969"
    sha256 sonoma:        "2850c10428981be834bdc49a327851eef8de34a67a82042d2cca7d742bddabcd"
    sha256 ventura:       "aaffb3619cd57eea72a6ca271d8fb1f117ed5ca3ceae968c7411988bdb5f835a"
    sha256 x86_64_linux:  "ea320d367c94317cf509d62a3f7dd787cb3fea668e0c41ad083ae00832106596"
  end

  depends_on "bash" => :build
  depends_on "pkgconf" => :build
  depends_on "sqlite" => [:build, :test]
  depends_on "libtommath"
  depends_on "libuv"
  depends_on "mimalloc"
  depends_on "openssl@3" # for OpenSSL module, loaded by path
  depends_on "readline" # for Readline module, loaded by path
  depends_on "zstd"

  uses_from_macos "perl" => :build
  uses_from_macos "libffi", since: :catalina
  uses_from_macos "libxml2"

  conflicts_with "moar", because: "both install `moar` binaries"
  conflicts_with "moarvm", "nqp", because: "rakudo-star currently ships with moarvm and nqp included"
  conflicts_with "parrot"
  conflicts_with "rakudo"

  # Apply open Config::Parser::json PR to fix unittests run during install
  # Ref: https://github.com/arjancwidlak/p6-Config-Parser-json/pull/1
  patch do
    url "https://github.com/arjancwidlak/p6-Config-Parser-json/commit/ca1a355c95178034b08ff9ebd1516a2e9d5bc067.patch?full_index=1"
    sha256 "d13230dc7d8ec0b72c21bd17e99a62d959fb3559d483eb43ce6be7ded8a0492a"
    directory "src/rakudo-star-modules/Config-Parser-json"
  end

  # Allow adding arguments via inreplace to unbundle libraries in MoarVM
  patch :DATA

  def install
    # Unbundle libraries in MoarVM
    moarvm_3rdparty = buildpath.glob("src/moarvm-*/MoarVM-*/3rdparty").first
    %w[dyncall libatomicops libtommath libuv mimalloc].each { |dir| rm_r(moarvm_3rdparty/dir) }
    moarvm_configure_args = %W[
      --c11-atomics
      --has-libffi
      --has-libtommath
      --has-libuv
      --has-mimalloc
      --pkgconfig=#{Formula["pkgconf"].opt_bin}/pkgconf
    ]
    inreplace "lib/actions/install.bash", "@@MOARVM_CONFIGURE_ARGS@@", moarvm_configure_args.join(" ")

    # Help Readline module find brew `readline` on Linux
    inreplace "src/rakudo-star-modules/Readline/lib/Readline.pm",
              %r{\((\n *)('/lib/x86_64-linux-gnu',)},
              "(\\1'#{Formula["readline"].opt_lib}',\\1\\2"

    ENV.deparallelize # An intermittent race condition causes random build failures.

    # make install runs tests that can hang on sierra
    # set this variable to skip those tests
    ENV["NO_NETWORK_TESTING"] = "1"

    # Help DBIish module find sqlite shared library
    ENV["DBIISH_SQLITE_LIB"] = Formula["sqlite"].opt_lib/shared_library("libsqlite3")

    # openssl module's brew --prefix openssl probe fails so
    # set value here
    openssl_prefix = Formula["openssl@3"].opt_prefix
    ENV["OPENSSL_PREFIX"] = openssl_prefix.to_s

    system "bin/rstar", "install", "-p", prefix.to_s

    #  Installed scripts are now in share/perl/{site|vendor}/bin, so we need to symlink it too.
    bin.install_symlink (share/"perl6/vendor/bin").children
    bin.install_symlink (share/"perl6/site/bin").children

    # Move the man pages out of the top level into share.
    # Not all backends seem to generate man pages at this point (moar does not, parrot does),
    # so we need to check if the directory exists first.
    share.install prefix/"man" if (prefix/"man").directory?
  end

  def post_install
    (share/"perl6/vendor/short").mkpath
  end

  test do
    out = shell_output("#{bin}/raku -e 'loop (my $i = 0; $i < 10; $i++) { print $i }'")
    assert_equal "0123456789", out

    # Test OpenSSL module
    (testpath/"openssl.raku").write <<~PERL
      use OpenSSL::CryptTools;
      my $ciphertext = encrypt("brew".encode, :aes256, :iv(("0" x 16).encode), :key(('x' x 32).encode));
      print decrypt($ciphertext, :aes256, :iv(("0" x 16).encode), :key(('x' x 32).encode)).decode;
    PERL
    assert_equal "brew", shell_output("#{bin}/raku openssl.raku")

    # Test Readline module
    (testpath/"readline.raku").write <<~PERL
      use Readline;
      my $response = Readline.new.readline("test> ");
      print "[$response]";
    PERL
    assert_equal "test> brew\n[brew]", pipe_output("#{bin}/raku readline.raku", "brew\n", 0)

    # Test LibXML module
    (testpath/"libxml.raku").write <<~PERL
      use LibXML::Document;
      my LibXML::Document $doc .=  parse: :string('<Hello/>');
      $doc.root.nodeValue = 'World!';
      print $doc<Hello>;
    PERL
    assert_equal "<Hello>World!</Hello>", shell_output("#{bin}/raku libxml.raku")

    # Test DBIish module
    (testpath/"sqlite.raku").write <<~PERL
      use DBIish;
      my $dbh = DBIish.connect("SQLite", :database<test.sqlite3>, :RaiseError);
      $dbh.execute("create table students (name text, age integer)");
      $dbh.execute("insert into students (name, age) values ('Bob', 14)");
      $dbh.execute("insert into students (name, age) values ('Sue', 12)");
      say $dbh.execute("select name from students order by age asc").allrows();
      $dbh.dispose;
    PERL
    assert_equal "([Sue] [Bob])\n", shell_output("#{bin}/raku sqlite.raku")

    # Test Config::Parser::json module
    (testpath/"test.json").write <<~JSON
      { "foo": { "bar": [0, 1] } }
    JSON
    (testpath/"parser.raku").write <<~PERL
      use Config;
      use Config::Parser::json;
      my $config = Config.new();
      $config.=read("test.json");
      print $config.get('foo.bar');
    PERL
    assert_equal "0 1", shell_output("#{bin}/raku parser.raku")
  end
end

__END__
--- a/lib/actions/install.bash
+++ b/lib/actions/install.bash
@@ -168,7 +168,7 @@ build_moarvm() {
 	fi
 
 	{
-		perl Configure.pl "$@" \
+		perl Configure.pl @@MOARVM_CONFIGURE_ARGS@@ "$@" \
 		&& make \
 		&& make install \
 		> "$logfile" \
