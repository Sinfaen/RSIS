using RSIS
load("sensor_rust")
test = newmodel("sensor_rust", "sr")
schedule(test, 10.0)