breed [
  gas-stations gas-station
]

breed [
  drivers driver
]

gas-stations-own [
  is-market-leader? ;; [false, true] false = is a market follower, true = is a market leader
  price-adjustment ;; price adjustment in cent -> market leaders adjust relative to raw oil price, market followers relative to market leaders
  price ;; current price per liter of gasoline
  customers-per-hour ;; sum of all customers of this gas station per hour
  profit-per-hour ;; price - raw-oil-price -> sum of all sales made by this gas station per hour
]

drivers-own [
  capacity ;; [40-80] Maximale kapazität: 40-80 Liter
  left-gasoline ;; [0-capacity] Wie viel noch im tank übrig ist
  picked-station ;; The gas station that the user picked from all of the posibilitis within the kilometer range he can reach
  price-sensitivity ;; [0-1]
  distance-sensitivity ;; [0-1]
  refuel-countdown ;; [0-10] (10 min) counts down the ticks that pass while refueling at a gas station
  sleeps-over-night;; tells if the drivers sleeps over night
  ;; Here eventually gasoline consumption per step
]

globals [
  nr-of-gas-stations ;; 5
  raw-oil-price ;; [1.00-1.30] the randomly set raw oil price
  gasoline-consumption-per-step
  refueling-duration
  max-distance
]

to setup
  clear-all
  set nr-of-gas-stations nr-of-stations
  set gasoline-consumption-per-step gasoline-consumption
  set refueling-duration 10
  set max-distance sqrt ((max-pxcor * max-pxcor) + (max-pycor * max-pycor))

  set-default-shape gas-stations "gas-station-1"
  set-default-shape drivers "car top"

  create-gas-stations nr-of-gas-stations [
    set is-market-leader? false
    set customers-per-hour []
    set price 1 + random 0.5
    set profit-per-hour []
    setxy random-xcor random-ycor
    set color red
    set size 3

  ]
  set-as-leader 0
  set-as-leader 1

  create-drivers nr-of-drivers [
    set capacity ((random 40) + 40)
    set left-gasoline capacity
    set distance-sensitivity random-float 1
    set price-sensitivity random-float 1
    setxy random-xcor random-ycor
    set sleeps-over-night random-float 1 < 0.5
    set size 2
  ]

  set raw-oil-price 1
  reset-ticks
end

to go
  do-plotting
  ifelse ticks mod 24 = 0 [
    init-new-day
  ][
    update-prices

      ask gas-stations[
        set label (word  precision price 3 )]

  ]
  move-drivers

  tick
end

to to-set-color-to-station
  ;; here comes the function to set the same colors as in the plot
end
to init-new-day
  set raw-oil-price 0.5 + (random-float 0.5)
  output-print (word "Day " (get-day + 1) " - raw oil price: " precision raw-oil-price 2 " €")

  ask gas-stations [
    ifelse is-market-leader? [
      set price raw-oil-price + price-adjustment
    ][
      let mean-price-of-leaders raw-oil-price + mean [price-adjustment] of gas-stations with [is-market-leader?] ;; prediction of mean leader prices
      set price mean-price-of-leaders + price-adjustment
    ]
    set customers-per-hour lput 0 customers-per-hour ;; setup the customer counter for the new hour
    set profit-per-hour lput 0 profit-per-hour ;; setup the profit counter for the new hour
  ]
end

to update-prices
  let customer-sum (customers-of-all-gas-stations (get-hour - 1))

  ask gas-stations [
    if customer-sum > 0 [
      let amount-to-adjust 0

      ;; calculate adjustment by competition
      foreach list-all-gas-stations [ station ->
        let price-diff [price] of station - price
        let market-share (item (get-hour - 1) ([customers-per-hour] of station)) / customer-sum
        let normalized-distance (max-distance - distance station) / max-distance
        set amount-to-adjust price-diff * market-share * normalized-distance
      ]

      ;; calculate adjustment by own demand
      let own-market-share (item (get-hour - 1) customers-per-hour) / customer-sum
      let average-market-share 1 / nr-of-gas-stations
      if own-market-share < average-market-share [
        let additional-amount-to-adjust 0
        ifelse own-market-share = 0 [
          set additional-amount-to-adjust (- customer-sum) / 100
        ][
          set additional-amount-to-adjust (- (average-market-share / own-market-share)) / 100
        ]
        set amount-to-adjust amount-to-adjust + additional-amount-to-adjust
      ]

      set price price + amount-to-adjust
      if price <= raw-oil-price [
        set price raw-oil-price
      ]
    ]

    set customers-per-hour lput 0 customers-per-hour ;; setup the customer counter for the new hour
    set profit-per-hour lput 0 profit-per-hour ;; setup the profit counter for the new hour
  ]
end

to move-drivers
  ;; I think over night, at least some of them should sleep i.e does not move to better match the reality
  let night member? get-hour [22 23 24 0 1 2 3 4 5 6]

  let active-drivers drivers
  if night = true [
    set active-drivers drivers with [sleeps-over-night = false]
  ]

  repeat 60 [
    ask active-drivers [
      ifelse compute-left-gasoline-ratio > drive-to-station-treshold [
        drive
      ][
        drive-to-station
      ]
    ]
  ]
end

to drive
  set left-gasoline left-gasoline - gasoline-consumption-per-step
  if left-gasoline > 0 [
    fd 1
  ]
end

to drive-to-station
  if picked-station = 0 [
    set picked-station find-best-gas-station
    face picked-station
  ]

  ifelse distance picked-station >= 1 [
    drive
  ][
    refuel
  ]
end

to refuel
  ifelse refuel-countdown = 0 [
    ;; this is executed, when the driver enters the gas station
    set refuel-countdown refueling-duration
    let liter capacity - left-gasoline
    ask picked-station [
      account-refueling liter
    ]
  ][
    if refuel-countdown = 1 [
      ;; this is executed, when refueling is finished (after waiting <refueling-duration> minutes at the gas station)
      set left-gasoline capacity
      set picked-station 0
      facexy ((random max-pxcor * 2) - max-pxcor) ((random max-pycor * 2) - max-pycor) ; choose a random patch within the map to face
    ]
  ]
  set refuel-countdown refuel-countdown - 1
end

to account-refueling [liter]
  set customers-per-hour replace-item get-hour customers-per-hour (item get-hour customers-per-hour + 1)
  set profit-per-hour replace-item get-hour profit-per-hour (item get-hour profit-per-hour + (liter * (price - raw-oil-price)))
end

to-report customers-of-all-gas-stations [hour]
  let customer-sum 0
  ask gas-stations [
    set customer-sum customer-sum + item hour customers-per-hour
  ]
  report customer-sum
end

to-report find-best-gas-station
  let possible-gas-stations search-gas-stations-in-range
  let best-station gas-station 0 ; set a random gas station to be overwritten
  let best-likeliness 100 ; set to a very high value to be overwritten by better solutions

  foreach possible-gas-stations [ station ->
    let likeliness compute-likeliness station

    if likeliness < best-likeliness [
      set best-likeliness likeliness
      set best-station station
    ]
  ]

  report best-station
end

to-report compute-likeliness [station]
  let price-summand price-sensitivity * [price] of station
  let distance-summand distance-sensitivity * (distance station / compute-remaining-range)
  report price-summand + distance-summand
end

to-report search-gas-stations-in-range
  let in-range []
  foreach list-all-gas-stations [ station ->
    if distance station < compute-remaining-range [
      set in-range lput station in-range
    ]
  ]
  report in-range
end

to-report list-all-gas-stations
  let stations []
  ask gas-stations [
    set stations lput self stations
  ]
  report stations
end

to-report compute-left-gasoline-ratio
    report left-gasoline / capacity * 100
end

to-report compute-remaining-range
  report left-gasoline * (1 / gasoline-consumption-per-step)
end

to set-as-leader [id]
  ask gas-station id [
    set is-market-leader? true
    set shape  "gas-station-leader"
    set price-adjustment random-float 0.15
    set size 4
  ]
end

to-report get-day
  report (ticks / 24)
end

to-report get-hour
  report ticks
end

to-report plot-price-of-station [number]
  let tmp 0
  ask gas-station number [
     set tmp price
  ]
  report tmp
end


to do-plotting


 ;;let stations  list-all-gas-stations
  ;;let av mean stations price

  ;;Ausgabe im Fitness-Plot
  set-current-plot "price/liter"
  set-current-plot-pen "1 L"
    plot plot-price-of-station 0
  set-current-plot-pen "2 L"
    plot plot-price-of-station 1
  set-current-plot-pen "3"
    plot plot-price-of-station 2
   set-current-plot-pen "4"
    plot plot-price-of-station 3
   set-current-plot-pen "5"
    plot plot-price-of-station 4

    set-current-plot "Raw Oil & Avg Gas Price"
  set-current-plot-pen "raw-oil"
    plot raw-oil-price
  set-current-plot-pen "av-price"
    plot mean [price] of gas-stations

end


to-report get-clock
  report (word "Day "precision (get-hour / 24)  -1 " - " (get-hour mod 24) ":00" )
end

to-report get-raw-oil-price
  report raw-oil-price
end
@#$#@#$#@
GRAPHICS-WINDOW
187
10
783
607
-1
-1
5.822
1
10
1
1
1
0
1
1
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
11
14
75
47
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
80
14
143
47
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
61
184
94
nr-of-drivers
nr-of-drivers
1
100
40.0
1
1
NIL
HORIZONTAL

PLOT
792
10
1330
222
Price/Liter
Time
Price
1.0
30.0
1.0
1.5
true
true
"" ""
PENS
"1 L" 1.0 0 -14730904 true "" ""
"2 L" 1.0 0 -7500403 true "" ""
"3" 1.0 0 -2674135 true "" ""
"4" 1.0 0 -955883 true "" ""
"5" 1.0 0 -6459832 true "" ""

MONITOR
791
232
917
293
Raw Oil Price 
get-raw-oil-price
5
1
15

SWITCH
10
100
148
133
show-labels?
show-labels?
0
1
-1000

SLIDER
12
142
184
175
drive-to-station-treshold
drive-to-station-treshold
10
50
25.0
5
1
NIL
HORIZONTAL

PLOT
927
231
1331
605
Raw Oil & Avg Gas Price
Price
Time
0.5
2.0
0.0
1.0
true
false
"" ""
PENS
"raw-oil" 1.0 0 -16777216 true "" ""
"av-price" 1.0 0 -5298144 true "" ""

SLIDER
11
182
185
215
gasoline-consumption
gasoline-consumption
0
1
0.17
0.01
1
NIL
HORIZONTAL

SLIDER
11
222
183
255
nr-of-stations
nr-of-stations
1
10
7.0
1
1
NIL
HORIZONTAL

MONITOR
791
298
915
343
Clock
get-clock
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

car top
true
0
Polygon -7500403 true true 151 8 119 10 98 25 86 48 82 225 90 270 105 289 150 294 195 291 210 270 219 225 214 47 201 24 181 11
Polygon -16777216 true false 210 195 195 210 195 135 210 105
Polygon -16777216 true false 105 255 120 270 180 270 195 255 195 225 105 225
Polygon -16777216 true false 90 195 105 210 105 135 90 105
Polygon -1 true false 205 29 180 30 181 11
Line -7500403 false 210 165 195 165
Line -7500403 false 90 165 105 165
Polygon -16777216 true false 121 135 180 134 204 97 182 89 153 85 120 89 98 97
Line -16777216 false 210 90 195 30
Line -16777216 false 90 90 105 30
Polygon -1 true false 95 29 120 30 119 11

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

gas-station
false
0
Rectangle -7500403 true true 56 18 219 276
Circle -7500403 true true 180 90 0
Rectangle -7500403 true true 21 275 253 294
Rectangle -7500403 false true 92 49 175 103
Rectangle -16777216 true false 73 46 200 103
Circle -16777216 false false 297 227 0
Rectangle -7500403 true true 261 87 270 120
Rectangle -7500403 true true 317 122 322 279
Rectangle -7500403 true true 210 75 270 90
Line -7500403 true 270 105 210 270

gas-station-1
false
0
Rectangle -7500403 true true 90 30 225 300
Rectangle -7500403 true true 45 285 270 300
Rectangle -16777216 true false 105 45 210 105
Rectangle -7500403 true true 225 60 285 75
Rectangle -7500403 true true 270 60 285 105
Line -7500403 true 285 105 225 285
Line -7500403 true 270 105 210 285

gas-station-leader
false
0
Rectangle -7500403 true true 90 30 225 300
Rectangle -7500403 true true 45 285 270 300
Rectangle -16777216 true false 105 45 210 105
Rectangle -7500403 true true 225 60 285 75
Rectangle -7500403 true true 270 60 285 105
Line -7500403 true 285 105 225 285
Line -7500403 true 270 105 210 285
Circle -7500403 true true 30 60 0
Polygon -1184463 false false 30 120 45 90 60 120 60 90 75 75 60 60 60 30 45 60 30 30 30 60 15 75 30 90 30 120 30 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
