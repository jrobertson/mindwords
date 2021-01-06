# Introducing the mindwords gem

    require 'mindwords'

    s = "
    milk #fridge
    cheese #fridge #kitchen
    cooker #kitchen
    fridge #kitchen
    paint #garage
    laptop #computers #acer
    kitchen #rooms
    rooms #house
    raspberrypi #computers
    car service #car
    car insurance #car
    car mot #car
    bitcoin #cryptocurrency #finances
    cryptocurrency #finances
    binance #accounts #cryptocurrency #finances #exchange
    accounts #cryptocurrency
    "

    mw = MindWords.new(s)
    puts mw.to_outline

Output:

<pre>
garage
  paint
computers
  laptop
  raspberrypi
house
  rooms
    kitchen
      cooker
      fridge
        milk
        cheese
car
  car service
  car insurance
  car mot
finances
  cryptocurrency
    bitcoin
    binance
    accounts
      binance
</pre>
