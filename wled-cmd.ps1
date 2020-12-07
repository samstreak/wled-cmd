Param([string]$ip,
      [string]$cmd,
      [string]$3,
      [string]$4
     )

function usage() {
  write-output "Usage: $0 ipaddress {on|off|get_brightness|set_brightness|color<2|3>|intensity|palette|cycle|fx|status}"
}

Enum http_codes {IsIpCorrect = 0; OK = 200; MovedPermanently = 300; BadRequest = 400; NotFound = 404; InternalServerError = 500; NotImplemented = 501}

function http_code([int]$code) {
  
  $tcode=[enum]::GetName([type] "http_codes", $code)

  if ( $tcode ) {
    echo "$tcode ($code)"
  } else {
    echo "$code"
  }
}

$octetRE="([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))"

if ( $ip  -notmatch "^($octetRE\.){3}$octetRE$" ) {
  echo "Missing or invalid IP address"
  usage
  exit 1
}


function on() {
  $rtn=curl "$baseURL&T=1"
  http_code $rtn.StatusCode
}

function off() {
  $rtn=curl "$baseURL&T=0"
  http_code $rtn.StatusCode
}

function get_brightness() {
  [xml]$content=(curl "$baseURL").Content
  $content.vs.ac
}

function set_brightness([byte]$bright) {

  if (! "$bright" ) {
    brightness_help
    exit 1
  }

  $old_brightness=get_brightness
  echo "Changing brightness from $old_brightness to $bright"
  $rtn=curl "$baseURL&A=$bright"
  http_code $rtn.StatusCode
  echo "Response: $(([xml]($rtn.Content)).vs.ac)"
}


function color([string]$cl, [switch]$color2, [switch]$color3) {
  if ( ! $cl ) {
    color_help
    exit 1
  }

  if ($cl -eq "?") {
    ([System.Drawing.Color] | gm -Static -MemberType Properties).name -join(", ")
    exit 1
  }

  if ($color2.IsPresent) {
   echo "Setting color2 to $cl"
  } elseif ($color3.IsPresent) {
   echo "Setting color3 to $cl"
  } else {
   echo "Setting color to $cl"
  }

  try {
   [int32]$icl = $cl
  } catch {
   if ($cl -match("<*,*,*>") -or $cl -match("{*,*,*}") -or $cl -match("[*,*,*]")) {
    
    $spl_cl = $cl.Substring(1, $cl.Length-2) -split(",")
    
    [int32]$icl = ([int32]$spl_cl[0] -shl 16) + ([int32]$spl_cl[1] -shl 8) + $spl_cl[2]

   } else {
    $sdc_cl = ([System.Drawing.Color]::$cl)
    if (! $sdc_cl) {echo "color $cl not found!. Please use a system 'known color' name."; exit 1}
    #echo "R: $($sdc_cl.R)`nG: $($sdc_cl.G)`nB: $($sdc_cl.B)"
    [int32]$icl = ([int32]$sdc_cl.R -shl 16) + ([int32]$sdc_cl.G -shl 8) + ($sdc_cl.B)
   }
  }

  $urlColor="CL"
  if ($color2.IsPresent) {
   $urlColor="C2"
  } elseif ($color3.IsPresent) {
   $urlColor="C3"
  }

  $rtn=curl "http://$ip/win&$urlColor=$icl"
  http_code $rtn.StatusCode

  if ($color2.IsPresent) {
   echo "Response: $(([xml]($rtn.Content)).vs.cs)"
  } elseif ($color3.IsPresent) {
   echo "XML response does not currently include tertiary color data."
  } else {
   echo "Response: $(([xml]($rtn.Content)).vs.cl)"
  }
}



function intensity([byte]$level) {

  $rtn=curl "http://$ip/win&IX=$level"
  http_code $rtn.StatusCode
  echo "Response: $(([xml]($rtn.Content)).vs.ix)"
}


function palette([string]$pal) {
 if (! $pal) {
  palette_help
  exit 1
 }
 
 $palettes=@()
 for ($i=0; $i -lt $config.palettes.Length; $i++) {
  $palettes+=@{"$i"=$config.palettes[$i]}
 }

 if ($pal -eq "?" -or [int]$pal -gt $config.palettes.Length) {
  write-output "Palette options:"
  $palettes|FT -AutoSize
  exit 1
 }

  $rtn=curl "http://$ip/win&FP=$pal"
  http_code $rtn.StatusCode

  echo "Response: $($palettes[([xml]($rtn.Content)).vs.fp].Values[0])"
}

function cycle([int]$duration, [int[]]$effect_list) {
  if (! $duration ) {
    cycle_help
    exit 1
  }

  if ( ! $effect_list ) {
    cycle_help
    exit 1
  }
  
  echo "This function runs in the background till WLED is turned off or brightness is set to zero"
  $bright=1
  $rtn=curl "http://$ip/win&A=$bright"
  while ($bright -gt 0 ) {
    foreach ($i in $effect_list) {
      $bright=get_brightness
      if ( $bright -eq 0 ) {
        return
      }
      #echo -n "Setting WLED effect $i, status: "
      $rtn=curl "http://$ip/win&T=1&FX=$i"
      #http_code $rtn.StatusCode
      start-sleep $duration
    }
  }
}

function fx([int]$fxnum) {
  if ( ! $fxnum ) {
    fx_help
    exit 1
  }

  $rtn=curl "http://$ip/win&T=1&FX=$fxnum"
  http_code $rtn.StatusCode
}

function status() {
  $rtn=curl "http://$ip/win"
  [xml]$content = $rtn.content
  echo $content.vs
}

function fx_help() {
  echo "fx requires a 3rd argument specifying the effect, list of effects is available here:"
  echo "https://github.com/Aircoookie/WLED/wiki/List-of-effects-and-palettes"
}

function brightness_help() {
  echo "brightness requires a 3rd argument specifying the brightness between 0 and 255"
}

function cycle_help() {
  echo "cycle requires a 3rd and 4th argument specifying the duration and effects list"
  echo "wled-cmd ipaddress cycle duration <comma separated effect list>"
  echo "wled-cmd 192.168.1.147 cycle 5 34,39,44,61,64,73,74,75,87,68,101,110"
}

function color_help() {
  echo "color requires a specified color to change to in one of the following formats:"
  echo "  1)  RGB:     [R, G, B] or {R, G, B} or <R, G, B>"
  echo "  2)  Named color:   i.e.  red, purple, lightblue, etc...  enter a ? as the color name for a list of valid color names."
  echo "  3)  Integer:   If you already know the integer value for the 24-bit color you want, enter it directly"
  echo ""
  echo "wled-cmd 192.168.1.147 color <255, 128,24>"
}

function palette_help() {
  echo "palette requires a specified palette number. enter a ? to show a list of valid palette numbers"
  echo ""
  echo "wled-cmd 192.168.1.147 palette 23"
}

$baseURL="http://$ip/win"
$config=ConvertFrom-Json (curl "http://$ip/json")



switch ("$cmd") {
    "on" {on; break}
    
    "off" {off; break}

    "get_brightness" {echo "Current brightness: $(get_brightness)"; break}

    "set_brightness" {set_brightness $3; break}

    "cycle"          {cycle $3 $4; break}
    
    "fx"             {fx $3; break}

    "status"         {status; break}

    "color"          {color $3; break}
    
    "color2"         {color $3 -color2; break}

    "color3"         {color $3 -color3; break}

    "intensity"      {intensity $3; break}

    "palette"        {palette $3; break}

    default          {echo "Missing command"; usage}
}
