yale_marcxml2accession_extras
=============================

Additional MARC XML -> Accession mappings for Yale

# Getting Started

Download the latest release from the Releases tab in Github:

  https://github.com/hudmol/yale_marcxml2accession_extras/releases

Unzip the release and move it to:

    /path/to/archivesspace/plugins

Unzip it:

    $ cd /path/to/archivesspace/plugins
    $ unzipyale_marcxml2accession_extras.zip -d yale_marcxml2accession_extras

Enable the plugin by editing the file in `config/config.rb`:

    AppConfig[:plugins] = ['some_plugin', 'yale_marcxml2accession_extras']

(Make sure you uncomment this line (i.e., remove the leading '#' if present))

See also:

  https://github.com/archivesspace/archivesspace/blob/master/plugins/README.md

