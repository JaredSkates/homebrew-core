class TclTk < Formula
  desc "Tool Command Language"
  homepage "https://www.tcl-lang.org"
  url "https://downloads.sourceforge.net/project/tcl/Tcl/9.0.2/tcl9.0.2-src.tar.gz"
  mirror "https://fossies.org/linux/misc/tcl9.0.2-src.tar.gz"
  sha256 "e074c6a8d9ba2cddf914ba97b6677a552d7a52a3ca102924389a05ccb249b520"
  license "TCL"

  livecheck do
    url :stable
    regex(%r{url=.*?/(?:tcl|tk).?v?(\d+(?:\.\d+)+)[._-]src\.t}i)
  end

  bottle do
    rebuild 1
    sha256 arm64_sequoia: "d3ad9d348307b2cbee9008df4f402f52e97e3fd77b67dc790a0f41377233fcda"
    sha256 arm64_sonoma:  "224a4b829fd506cbf2787c6d458190f703fbd9fd8d3d83cd4b5e4082dea8d8d3"
    sha256 arm64_ventura: "c92b9d4f1b4695c58768708581eb74b76b4c72bcc08579475f29b16e402cbd42"
    sha256 sonoma:        "3f91ac61087c64dc81d58a8bc86061d193434bf21dd0393d0d7611acf996a752"
    sha256 ventura:       "321f4188c72b4336032fb77b66e35ad48727027434ea7c03cab8b738738e1038"
    sha256 arm64_linux:   "e3a8cb7f42094c82a9b90fcaa6d0f3f6a7b9b4110baeb31ab871c50904fb70d4"
    sha256 x86_64_linux:  "25eb63c4e70e251900962c2ee2faba9bb76790223e16c19e3d142f5b823dae55"
  end

  depends_on "libtommath"
  depends_on "openssl@3"

  uses_from_macos "zlib"

  on_linux do
    depends_on "freetype" => :build
    depends_on "pkgconf" => :build
    depends_on "libx11"
    depends_on "libxext"
  end

  conflicts_with "page", because: "both install `page` binaries"
  conflicts_with "the_platinum_searcher", because: "both install `pt` binaries"

  resource "critcl" do
    url "https://github.com/andreas-kupries/critcl/archive/refs/tags/3.3.1.tar.gz"
    sha256 "d970a06ae1cdee7854ca1bc571e8b5fe7189788dc5a806bce67e24bbadbe7ae2"

    livecheck do
      regex(/^v?(\d+(?:\.\d+)+)$/i)
    end
  end

  resource "tcllib" do
    url "https://downloads.sourceforge.net/project/tcllib/tcllib/2.0/tcllib-2.0.tar.xz"
    sha256 "642c2c679c9017ab6fded03324e4ce9b5f4292473b62520e82aacebb63c0ce20"
  end

  # There is no tcltls release compatible with TCL 9 so using latest
  # check-in at https://core.tcl-lang.org/tcltls/timeline
  # Ref: https://core.tcl-lang.org/tcltls/tktview/f5a0fe8ddf
  # Ref: https://sourceforge.net/p/tcl/mailman/tcl-core/thread/eab3a8bf-b846-45ef-a80c-6bc94d6dfe91@elmicron.de/
  resource "tcltls" do
    url "https://core.tcl-lang.org/tcltls/tarball/e03e54ee87/tcltls-e03e54ee87.tar.gz"
    sha256 "db473afa98924c0a2b44ecacea35bb2609e6810de1df389ad55bb3688023f8d1"
  end

  resource "tk" do
    url "https://downloads.sourceforge.net/project/tcl/Tcl/9.0.2/tk9.0.2-src.tar.gz"
    mirror "https://fossies.org/linux/misc/tk9.0.2-src.tar.gz"
    sha256 "76fb852b2f167592fe8b41aa6549ce4e486dbf3b259a269646600e3894517c76"

    livecheck do
      formula :parent
    end
  end

  # "https://downloads.sourceforge.net/project/incrtcl/%5Bincr%20Tcl_Tk%5D-4-source/itk%204.1.0/itk4.1.0.tar.gz"
  # would cause `bad URI(is not URI?)` error on 12/13 builds
  # Also need a newer release than available on SourceForce for TCL 9
  # so we use the GitHub mirror which is easier to access than Fossil
  resource "itk4" do
    url "https://github.com/tcltk/itk/archive/refs/tags/itk-4-2-3.tar.gz"
    version "4.2.3"
    sha256 "bc5ed347212fce403e04d3161cd429319af98da47effd3e32e20d2f04293b036"
  end

  def install
    odie "tk resource needs to be updated" if version != resource("tk").version

    # Remove bundled libraries. Some private headers are still needed
    ["compat/zlib", "libtommath"].each do |dir|
      (buildpath/dir).find do |path|
        rm(path) if path.file? && path.extname != ".h"
      end
    end

    args = %W[
      --prefix=#{prefix}
      --includedir=#{include}/tcl-tk
      --mandir=#{man}
      --disable-zipfs
      --enable-man-suffix
      --enable-64bit
    ]

    ENV["TCL_PACKAGE_PATH"] = "#{HOMEBREW_PREFIX}/lib"
    cd "unix" do
      system "./configure", *args, "--with-system-libtommath"
      system "make"
      system "make", "install"
      system "make", "install-private-headers"
      bin.install_symlink "tclsh#{version.to_f}" => "tclsh"
    end

    # Let tk finds our new tclsh
    ENV.prepend_path "PATH", bin

    resource("tk").stage do
      cd "unix" do
        args << "--enable-aqua=yes" if OS.mac?
        system "./configure", *args, "--without-x", "--with-tcl=#{lib}"
        system "make"
        system "make", "install"
        system "make", "install-private-headers"
        bin.install_symlink "wish#{version.to_f}" => "wish"
      end
    end

    resource("critcl").stage do
      system bin/"tclsh", "build.tcl", "install"
    end

    resource("tcllib").stage do
      system "./configure", "--prefix=#{prefix}", "--mandir=#{man}"
      system "make", "install"
      system "make", "critcl"
      cp_r "modules/tcllibc", "#{lib}/"
      ln_s "#{lib}/tcllibc/macosx-x86_64-clang", "#{lib}/tcllibc/macosx-x86_64" if OS.mac?
    end

    resource("tcltls").stage do
      system "./configure", "--with-openssl-dir=#{Formula["openssl@3"].opt_prefix}",
                            "--prefix=#{prefix}",
                            "--with-tcl=#{lib}",
                            "--with-tclinclude=#{include}/tcl-tk",
                            "--mandir=#{man}"
      system "make", "install"
    end

    resource("itk4").stage do
      itcl_dir = lib.glob("itcl*").last
      # Workaround to build non-release tarball by using TEA files from itcl
      odie "Update `itk4` build step!" if Pathname("tclconfig").exist?
      Pathname.pwd.install_symlink buildpath/"pkgs/#{itcl_dir.basename}/tclconfig"

      args = %W[
        --prefix=#{prefix}
        --exec-prefix=#{prefix}
        --with-tcl=#{lib}
        --with-tclinclude=#{include}/tcl-tk
        --with-tk=#{lib}
        --with-tkinclude=#{include}/tcl-tk
        --with-itcl=#{itcl_dir}
      ]
      system "./configure", *args
      system "make"
      system "make", "install"
    end

    # Use the sqlite-analyzer formula instead
    # https://github.com/Homebrew/homebrew-core/pull/82698
    rm bin/"sqlite3_analyzer"
  end

  def caveats
    <<~EOS
      The sqlite3_analyzer binary is in the `sqlite-analyzer` formula.
    EOS
  end

  test do
    assert_match "#{HOMEBREW_PREFIX}/lib", pipe_output("#{bin}/tclsh", "puts $auto_path\n")
    assert_equal "honk", pipe_output("#{bin}/tclsh", "puts honk\n").chomp

    # Fails with: no display name and no $DISPLAY environment variable
    return if OS.linux? && ENV["HOMEBREW_GITHUB_ACTIONS"]

    test_itk = <<~TCL
      # Check that Itcl and Itk load, and that we can define, instantiate,
      # and query the properties of a widget.


      # If anything errors, just exit
      catch {
          package require Itcl
          package require Itk

          # Define class
          itcl::class TestClass {
              inherit itk::Toplevel
              constructor {args} {
                  itk_component add bye {
                      button $itk_interior.bye -text "Bye"
                  }
                  eval itk_initialize $args
              }
          }

          # Create an instance
          set testobj [TestClass .#auto]

          # Check the widget has a bye component with text property "Bye"
          if {[[$testobj component bye] cget -text]=="Bye"} {
              puts "OK"
          }
      }
      exit
    TCL
    assert_equal "OK\n", pipe_output("#{bin}/wish", test_itk), "Itk test failed"
  end
end
