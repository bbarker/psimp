module PatternMatch where

import Prelude

-- Constructor
data Something
  = Sum
  | Product Int String

cpm :: Something -> String
cpm Sum = "sum"

cpm (Product i s)
  | i == 7 = "product seven"
  | s == "lucky" = "product lucky"

cpm _ = "some product"

-- Array
apm :: Array String -> String
apm [] = "empty"

apm [ a ] = a

apm [ a, b ] = a <> "," <> b

apm _ = "some"
