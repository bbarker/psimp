module CodeGen.Go.Printer where

import Prelude hiding (Ordering(..))
import CodeGen.Go.AST (BinOp(..), Expr(..), Lit(..), Prefix(..), Stat(..), UnOp(..))
import Data.Array (null)
import Data.Foldable (intercalate)
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Prettier.Printer (DOC, line, nest, nil, pretty, text)

word ::
  { func :: DOC
  , if :: DOC
  , import :: DOC
  , len :: DOC
  , package :: DOC
  , panic :: DOC
  , return :: DOC
  , var :: DOC
  }
word =
  { var: text "var"
  , func: text "func"
  , return: text "return"
  , if: text "if"
  , import: text "import"
  , package: text "package"
  , panic: text "panic"
  , len: text "len"
  }

bracket ::
  { curlyClose :: DOC
  , curlyOpen :: DOC
  , roundClose :: DOC
  , roundOpen :: DOC
  , squareClose :: DOC
  , squareOpen :: DOC
  }
bracket =
  { roundOpen: text "("
  , roundClose: text ")"
  , curlyOpen: text "{"
  , curlyClose: text "}"
  , squareOpen: text "["
  , squareClose: text "]"
  }

helper ::
  { any :: DOC
  , apply :: DOC
  , array :: DOC
  , dict :: DOC
  }
helper =
  { apply: text "Apply"
  , any: text "Any"
  , array: text "[]Any"
  , dict: text "Dict"
  }

equal :: DOC
equal = text "="

comma :: DOC
comma = text ","

dot :: DOC
dot = text "."

colon :: DOC
colon = text ":"

stat :: Stat -> DOC
stat (VarAssign a b) = joinSpace [ word.var, text a, equal, expr b ]

stat (Assign v x) = joinSpace [ expr v, equal, expr x ]

stat (If cond stats) =
  joinSpace [ word.if, expr cond, bracket.curlyOpen ]
    <> indent (line <> (intercalate line (map stat stats)))
    <> line
    <> bracket.curlyClose

stat (Return x) = joinSpace [ word.return, expr x ]

stat (Import paths) =
  joinSpace [ word.import, bracket.roundOpen ]
    <> indent (line <> (intercalate line (map prt paths)))
    <> line
    <> bracket.roundClose
  where
  prt (Tuple (Just p) path) = joinSpace [ prefix p, text (show path) ]

  prt (Tuple Nothing path) = text (show path)

stat (Package name) = joinSpace [ word.package, text name ]

stat (Throw s) = joinEmpty [ word.panic, bracket.roundOpen, text (show s), bracket.roundClose ]

stat (FunctionDecl name arg stats) =
  joinSpace
    [ word.func
    , joinEmpty [ text name, bracket.roundOpen ]
    ]
    <> joinSpace [ text arg, helper.any ]
    <> joinSpace [ bracket.roundClose, helper.any, bracket.curlyOpen ]
    <> indent (line <> (intercalate line (map stat stats)))
    <> line
    <> bracket.curlyClose

stat (Raw s) = text s

prefix :: Prefix -> DOC
prefix Dot = dot

expr :: Expr -> DOC
expr (Var v) = text v

-- REVIEW: clean way to copy object
expr (Clone x) =
  text
    """(func()
                _res := make(Dict)
                for key, value := range """
    <> expr x
    <> text
        """ {
                    _res[_k] = _v
                }
                return _res
            })()"""

expr (Literal l) = lit l

expr (Referrer s x) = joinEmpty [ text s, dot, text x ]

expr (Accessor a x) =
  joinEmpty
    [ expr x
    , dot
    , bracket.roundOpen
    , helper.dict
    , bracket.roundClose
    , bracket.squareOpen
    , text (show a)
    , bracket.squareClose
    ]

expr (Indexer i x) =
  joinEmpty
    [ expr x
    , bracket.squareOpen
    , text (show i)
    , bracket.squareClose
    ]

expr (App f x) =
  joinEmpty
    [ helper.apply
    , bracket.roundOpen
    , expr f
    , joinSpace [ comma, expr x ]
    , bracket.roundClose
    ]

expr (Function arg stats) =
  word.func
    <> bracket.roundOpen
    <> joinSpace [ text arg, helper.any ]
    <> joinSpace [ bracket.roundClose, helper.any, bracket.curlyOpen ]
    <> indent (line <> (intercalate line (map stat stats)))
    <> line
    <> bracket.curlyClose

expr (Binary op a b) = joinSpace [ expr a, bin op, expr b ]

expr (Unary op x) = joinSpace [ un op, expr x ]

expr (Length arr) =
  joinEmpty
    [ word.len
    , bracket.roundOpen
    , expr arr
    , dot
    , bracket.roundOpen
    , helper.array
    , bracket.roundClose
    , bracket.roundClose
    ]

expr Nil = text "nil"

bin :: BinOp -> DOC
bin Eq = text "=="

bin Neq = text "!="

bin Gt = text ">"

bin Gte = text ">="

bin Lt = text "<"

bin Lte = text "<="

bin Add = text "+"

bin Sub = text "-"

bin Mul = text "*"

bin Div = text "/"

bin Mod = text "%"

bin And = text "&&"

bin Or = text "||"

un :: UnOp -> DOC
un Neg = text "-"

un Not = text "!"

lit :: Lit -> DOC
lit (Int i) = text $ show i

lit (Number n) = text $ show n

lit (Boolean b) = text $ show b

lit (String s) = text $ show s

lit (Array xs) =
  helper.array
    <> bracket.curlyOpen
    <> intercalate comma (map expr xs)
    <> bracket.curlyClose

lit (Object kvs) =
  helper.dict
    <> bracket.curlyOpen
    <> indent
        ( ( intercalate comma
              $ map
                  (\(Tuple k v) -> line <> joinSpace [ joinEmpty [ text (show k), colon ], expr v ])
                  kvs
          )
            <> if null kvs then nil else comma
        )
    <> line
    <> bracket.curlyClose

joinSpace :: Array DOC -> DOC
joinSpace = intercalate (text " ")

joinEmpty :: Array DOC -> DOC
joinEmpty = intercalate (text "")

indent :: DOC -> DOC
indent = nest 4

print :: Array Stat -> String
print = pretty top <<< intercalate line <<< map statEndWithLine
  where
  statEndWithLine s = stat s <> line
