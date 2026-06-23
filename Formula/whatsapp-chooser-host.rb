class WhatsappChooserHost < Formula
  desc "Native messaging host for the WhatsApp Chooser Chrome extension"
  homepage "https://github.com/onemanjoe/whatsapp-chooser"
  url "https://github.com/onemanjoe/whatsapp-chooser/archive/refs/tags/v1.2.tar.gz"
  sha256 "11012dd3e3d6b95efc4c26aded78ad7593786d05d7714722815f0745b1eaa490"
  license "MIT"

  depends_on :macos

  def install
    # Compile the tiny C host from source on the user's machine. Building locally
    # means the binary is never quarantined, so Chrome can launch it without a
    # Gatekeeper prompt and without any code-signing.
    system ENV.cc, "-O2", "-o", "host", "native-host/host.c"
    libexec.install "host"
    bin.install "native-host/whatsapp-chooser-host"
  end

  def caveats
    <<~EOS
      One-time setup:

        whatsapp-chooser-host configure    # set your WhatsApp app names
        whatsapp-chooser-host register     # register with Google Chrome

      Then fully quit Chrome (Cmd+Q) and reopen it.

      You also need the "WhatsApp Chooser" extension from the Chrome Web Store.
    EOS
  end

  test do
    assert_predicate libexec/"host", :executable?
    assert_match "whatsapp-chooser-host", shell_output("#{bin}/whatsapp-chooser-host help")
  end
end
