class Tinysparql < Formula
  desc "Low-footprint RDF triple store with SPARQL 1.1 interface"
  homepage "https://tinysparql.org/"
  url "https://download.gnome.org/sources/tinysparql/3.9/tinysparql-3.9.1.tar.xz"
  sha256 "98e8933b946d8c54a77eadabd7f1d14cddd88fa43eef0d0ace3c0fcce646722b"
  license all_of: ["LGPL-2.1-or-later", "GPL-2.0-or-later"]
  head "https://gitlab.gnome.org/GNOME/tinysparql.git", branch: "main"

  # TinySPARQL doesn't follow GNOME's "even-numbered minor is stable" version
  # scheme but they do appear to use 90+ minor/patch versions, which may
  # indicate unstable versions (e.g., 1.99.0, 2.2.99.0, etc.).
  livecheck do
    url "https://download.gnome.org/sources/tinysparql/cache.json"
    regex(/tinysparql[._-]v?(\d+(?:(?!\.9\d)\.\d+)+)\.t/i)
  end

  bottle do
    sha256 arm64_linux:  "5c284fccef5b0b7af359a9fc4cffce37aed9ec4205d909b2c25da39609a1c9e1"
    sha256 x86_64_linux: "2289bb008fc9bad101d446e7ac5b03d22bd568eacbad0f9ea6bc38149a7c04da"
  end

  depends_on "gettext" => :build
  depends_on "gobject-introspection" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => [:build, :test]
  depends_on "vala" => :build

  depends_on "dbus"
  depends_on "glib"
  depends_on "icu4c@77"
  depends_on "json-glib"
  depends_on "libsoup"
  depends_on "libxml2"
  depends_on :linux # macOS fatal error: 'gio/gdesktopappinfo.h' file not found
  depends_on "sqlite"

  conflicts_with "tracker", because: "both install the same libraries"

  def install
    args = %w[
      -Dman=false
      -Ddocs=false
      -Dsystemd_user_services=false
      -Dtests=false
    ]

    ENV["DESTDIR"] = "/"

    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <libtracker-sparql/tracker-sparql.h>

      gint main(gint argc, gchar *argv[]) {
        g_autoptr(GError) error = NULL;
        g_autoptr(GFile) ontology;
        g_autoptr(TrackerSparqlConnection) connection;
        g_autoptr(TrackerSparqlCursor) cursor;
        int i = 0;

        ontology = tracker_sparql_get_ontology_nepomuk();
        connection = tracker_sparql_connection_new(0, NULL, ontology, NULL, &error);

        if (error) {
          g_critical("Error: %s", error->message);
          return 1;
        }

        cursor = tracker_sparql_connection_query(connection, "SELECT ?r { ?r a rdfs:Resource }", NULL, &error);

        if (error) {
          g_critical("Couldn't query: %s", error->message);
          return 1;
        }

        while (tracker_sparql_cursor_next(cursor, NULL, &error)) {
          if (error) {
            g_critical("Couldn't get next: %s", error->message);
            return 1;
          }
          if (i++ < 5) {
            if (i == 1) {
              g_print("Printing first 5 results:");
            }

            g_print("%s", tracker_sparql_cursor_get_string(cursor, 0, NULL));
          }
        }

        return 0;
      }
    C

    icu4c = deps.find { |dep| dep.name.match?(/^icu4c(@\d+)?$/) }
                .to_formula
    ENV.prepend_path "PKG_CONFIG_PATH", icu4c.opt_lib/"pkgconfig"
    flags = shell_output("pkgconf --cflags --libs tracker-sparql-3.0").chomp.split
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end
