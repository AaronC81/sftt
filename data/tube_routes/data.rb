# NOTE: KGX and SPX are functionally the same Tube station.
# Can't do anything which assumes uniqueness.
#
# Map CRS codes to NAPTAN identifiers of the Tube stations which can be considered the same station.
CRS_TO_NAPTAN = {
  'KGX' => '940GZZLUKSX',
  'SPX' => '940GZZLUKSX',
  'BFR' => '940GZZLUBKF',
  'CST' => '940GZZLUCST',
  'CHX' => '940GZZLUCHX',
  'EUS' => '9400ZZLUEUS',
  'LST' => '9400ZZLULVT',
  'LBG' => '940GZZLULNB',
  'MYB' => '940GZZLUMYB',
  'MOG' => '940GZZLUMGT',
  'OLD' => '9400ZZLUODS',
  'PAD' => '9400ZZLUPAC',
  'VHX' => '9400ZZLUVXL',
  'VIC' => '940GZZLUVIC',
  'WAT' => '940GZZLUWLO',
  'EPH' => '940GZZLUEAC',
  'ZFD' => '940GZZLUFCN',

  # City Thameslink (CTK) does not have its own station
  # Fenchurch Street (FST) technically doesn't, but it's considered part of Tower Hill on the map
  # Waterloo East (WAE) doesn't either, but you could walk to Waterloo
}
