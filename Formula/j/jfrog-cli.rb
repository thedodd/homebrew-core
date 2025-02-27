class JfrogCli < Formula
  desc "Command-line interface for JFrog products"
  homepage "https://www.jfrog.com/confluence/display/CLI/JFrog+CLI"
  url "https://github.com/jfrog/jfrog-cli/archive/refs/tags/v2.74.0.tar.gz"
  sha256 "f0e6d568c0b053c45cd0165bfc03ae6c806cdb602418ffa05b0e30dd4ad8c684"
  license "Apache-2.0"
  head "https://github.com/jfrog/jfrog-cli.git", branch: "v2"

  # There can be a notable gap between when a version is tagged and a
  # corresponding release is created, so we check the "latest" release instead
  # of the Git tags.
  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "d8c091557bae63e117e2f4ed34ca2a10f10edec98c4740687908a40bf9f44bc6"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "d8c091557bae63e117e2f4ed34ca2a10f10edec98c4740687908a40bf9f44bc6"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "d8c091557bae63e117e2f4ed34ca2a10f10edec98c4740687908a40bf9f44bc6"
    sha256 cellar: :any_skip_relocation, sonoma:        "ac632d95df4ae572da7f8eea4856d0464ee69675948bc57f2a83cd9e582dbfee"
    sha256 cellar: :any_skip_relocation, ventura:       "ac632d95df4ae572da7f8eea4856d0464ee69675948bc57f2a83cd9e582dbfee"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "2eb7409d1b7f3f0803d7a7129e1a6efe888c2c66629597899406315712d1c09e"
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w", output: bin/"jf")
    bin.install_symlink "jf" => "jfrog"

    generate_completions_from_executable(bin/"jf", "completion")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/jf -v")
    assert_match version.to_s, shell_output("#{bin}/jfrog -v")
    with_env(JFROG_CLI_REPORT_USAGE: "false", CI: "true") do
      assert_match "build name must be provided in order to generate build-info",
        shell_output("#{bin}/jf rt bp --dry-run --url=http://127.0.0.1 2>&1", 1)
    end
  end
end
