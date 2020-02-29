-- constructor: tag NEWLINEW n-ary NEWLINEW ary1 NEWLINEW ary2 NEWLINEW ary3 ...
-- literal: "literal" SPACE kind SPACE n-length SPACE char1...charn
--   literal kind could be "int", "float", "char", "string", "bigInt", so far
module Quick.Dump where

data LitKind
  = Float
  | Int
  | Char
  | Str
  | BigInt
  | Symbol
  | Boolean
  | Unit

data DumpTree
  = CtorNode
      { treeCons :: String
      , components :: [DumpTree]
      }
  | Leaf
      { litKind :: LitKind
      , litStr :: String
      }
  | ListNode [DumpTree]

dumpKind =
  \case
    Float -> "float"
    Int -> "int"
    Char -> "char"
    Str -> "string"
    BigInt -> "bigInt"
    Symbol -> "symbol"
    Boolean -> "bool"
    Unit -> "unit"

dumpTree :: DumpTree -> String
dumpTree =
  \case
    CtorNode cons comp ->
      let n = length comp
       in unlines $ unwords ["constructor", cons, show n] : map dumpTree comp
    Leaf kind str ->
      let n = length str
       in unlines [unwords ["literal", dumpKind kind, show n], str]
    ListNode xs ->
      let n = length xs
       in unlines $ unwords ["list", show n] : map dumpTree xs

class Dumpable a where
  dump :: a -> DumpTree

dumpList xs = ListNode $ map dump xs