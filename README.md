# SFTT

SFTT is a pair of command-line tools for creating simplified train timetables for the UK rail network.

Considering a train route from X to Z, there are two levels of detail you might want:

1. "There is a train leaving X at 12:41, which will take 21 minutes to get to Y. Change at Y to board the 13:05 to Z, which takes 8 minutes."
2. "It takes about 20 minutes to get from X to Y, then about 10 minutes to get from Y to Z."

SFTT covers case 2. It outputs JSON files which summarise travel times and transfers from all stations to a particular destination. You can then instantly look up approximate travel times from this file.

## Prerequisites

### Data

SFTT's input is a zipped timetable file from National Rail Open Data. [Refer to this guide](https://wiki.openraildata.com/index.php/DTD) for details on how to obtain this. (The zip should contain files with extensions like `.MCA` and `.ALF`.)

### System

This needs quite a lot of dependencies:

- A JAR of [OpenTripPlanner](https://www.opentripplanner.org/) 2.x
- An installation of Java capable of running your OpenTripPlanner version
- Ruby 3.4 or above (plus dependencies in the Gemfile)
- R, tested on 4.5.2
- The UK2GTFS package for R: `https://github.com/ITSleeds/UK2GTFS`
    - First, install `remotes`: `install.packages("remotes")`
    - Then, install the package: `remotes::install_github("ITSleeds/UK2GTFS")`
    - You may need to install various packages on your system - in my experience on RHEL, these were:
        - `cmake`
        - `libcurl-devel`
        - `udunits2-devel`
        - `gdal310-devel` (and maybe `gdal310-libs`)
            - I had to create symlinks named `/usr/bin/gdal-config[-64]` pointing to `/usr/bin/gdal310-config[-64]` for one of the package dependency build scripts to detect this correctly
        - `proj-devel`
        - `geos-devel`

Java is started with 16GB of RAM; on my machine (M1 Pro) any less than this isn't sufficient for OpenTripPlanner to start.

## Usage

### Step 1: Config Generation

SFTT generates a set of configuration files for [OpenTripPlanner](https://www.opentripplanner.org/). This is mainly handled by the [UK2GTFS](https://itsleeds.github.io/UK2GTFS/) library, with some post-processing to clean up the data for OpenTripPlanner, and additional generation for walking transfers.

```sh
ruby src/sftt/config_generator/main.rb --input [PATH] --output otp-config
```

(Where `[PATH]` is a **directory** which contains your timetable zip, **named exactly `timetable.zip`**.)

### Step 2: Route Extraction

Once you have OpenTripPlanner configuration, SFTT's second step will start it and query for all routes, then dump them into a JSON file.

```sh
ruby src/sftt/route_extractor/main.rb ^
    --otp-config otp-config ^
    --otp-jar ~/Downloads/otp*.jar ^
    --to LEEDS
    --output LEEDS.json
```

## TODO

There's still stuff I want to improve for my own use-case:

- Improve routes by removing similar/useless ones
- It'd be nice if this covered the Tube network too
- CRS would make more sense than TIPLOC
- Add options to snap times into averages/approximates, e.g. "45 minutes" rather than "39 minutes"
