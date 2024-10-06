class Mesheryctl < Formula
  desc "Command-line utility for Meshery, the cloud native management plane"
  homepage "https://meshery.io"
  url "https://github.com/meshery/meshery.git",
      tag:      "v0.7.117",
      revision: "167089b8a085c9d4f523687313fc9a8a07b6fb1b"
  license "Apache-2.0"
  head "https://github.com/meshery/meshery.git", branch: "master"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "558587ba878bb12ed2eda9981e2948175cd426e4dd6cc88a4a200a466e365286"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "558587ba878bb12ed2eda9981e2948175cd426e4dd6cc88a4a200a466e365286"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "558587ba878bb12ed2eda9981e2948175cd426e4dd6cc88a4a200a466e365286"
    sha256 cellar: :any_skip_relocation, sonoma:        "79fbf1fc6fdf169ecc0a47e6f62f1b35e059d12b183f5270b7f792b421e01794"
    sha256 cellar: :any_skip_relocation, ventura:       "79fbf1fc6fdf169ecc0a47e6f62f1b35e059d12b183f5270b7f792b421e01794"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "1ab738eb57aafa3256d28adc06dacf561061ddf3f82f1d16e18a915a0caf0f6a"
  end

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"

    ldflags = %W[
      -s -w
      -X github.com/layer5io/meshery/mesheryctl/internal/cli/root/constants.version=v#{version}
      -X github.com/layer5io/meshery/mesheryctl/internal/cli/root/constants.commitsha=#{Utils.git_short_head}
      -X github.com/layer5io/meshery/mesheryctl/internal/cli/root/constants.releasechannel=stable
    ]

    system "go", "build", *std_go_args(ldflags:), "./mesheryctl/cmd/mesheryctl"

    generate_completions_from_executable(bin/"mesheryctl", "completion")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mesheryctl version 2>&1")
    assert_match "Channel: stable", shell_output("#{bin}/mesheryctl system channel view 2>&1")

    # Test kubernetes error on trying to start meshery
    assert_match "The Kubernetes cluster is not accessible.", shell_output("#{bin}/mesheryctl system start 2>&1", 1)
  end
end
