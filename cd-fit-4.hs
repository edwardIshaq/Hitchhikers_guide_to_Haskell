module Main where
import Data.List (sortBy)
import Text.ParserCombinators.Parsec
import Test.QuickCheck
import Control.Monad (liftM2, replicateM)
import Data.Ix (inRange)
import Data.List (maximumBy)
-- parseInput parses output of "du -sb", which consists of many lines,
-- ON MAC:  du -h 1  ~/Downloads
-- each of which describes single directory
parseInput =
  do dirs <- many dirAndSize
     eof :: Parser ()
     return dirs


-- Datatype Dir holds information about single directory - its size and name
data Dir = Dir {dir_size::Integer, dir_name::String} deriving Show

instance Eq Dir where
   (==) dirA dirB = (dir_size dirA == dir_size dirB) && (dir_name dirA == dir_name dirB)

-- DirPack holds a set of directories which are to be stored on single CD.
-- 'pack_size' could be calculated, but we will store it separately to reduce
-- amount of calculation
data DirPack = DirPack {pack_size::Integer, dirs::[Dir]} deriving Show

-- For simplicity, let's assume that we deal with standard 700 Mb CDs for now
media_size = 700*1024*1024

-- Greedy packer tries to add directories one by one to initially empty 'DirPack'
greedy_pack dirs = foldl maybe_add_dir (DirPack 0 []) $ sortBy cmpSize dirs
  where
  cmpSize d1 d2 = compare (dir_size d1) (dir_size d2)

-- Helper function, which only adds directory "d" to the pack "p" when new
-- total size does not exceed media_size
maybe_add_dir p d =
  let new_size = pack_size p + dir_size d
      new_dirs = d : dirs p
      in if new_size > media_size then p else DirPack new_size new_dirs

--
-- `dirAndSize` parses information about single directory, which is:
-- a size in bytes (number), some spaces, then directory name, which extends till newline
dirAndSize =
  do size <- many1 digit
     spaces
     dir_name <- anyChar `manyTill` newline
     return (Dir (read size) dir_name)

moin = do input <- getContents
          putStrLn ("DEBUG: got input " ++ input)
          let dirs = case parse parseInput "stdin" input of
                         Left err -> error $ "Input:\n" ++ show input ++
                                             "\nError:\n" ++ show err
                         Right result -> result
          putStrLn "DEBUG: parsed:"; print dirs
          -- compute solution and print it
          putStrLn "Solution:" ; print (greedy_pack dirs)


-- We must teach QuickCheck how to generate arbitrary "Dir"s
instance Arbitrary Dir where
  -- Let's just skip "coarbitrary" for now, ok?
  -- I promise, we will get back to it later :)

  -- coarbitrary = undefined

  -- We generate arbitrary "Dir" by generating random size and random name
  -- and stuffing them inside "Dir"
  arbitrary = liftM2 Dir gen_size gen_name
          -- Generate random size between 10 and 1400 Mb
    where gen_size = do s <- choose (10,1400)
                        return (s*1024*1024)
          -- Generate random name 1 to 300 chars long, consisting of symbols "fubar/"
          gen_name = do n <- choose (1,300)
                        replicateM n (elements "fubar/")

-- For convenience and by tradition, all QuickCheck tests begin with prefix "prop_".
-- Assume that "ds" will be a random list of "Dir"s and code your test.
prop_greedy_pack_is_fixpoint ds =
  let pack = greedy_pack ds
      in pack_size pack == pack_size (greedy_pack (dirs pack))



-- Taken from 'cd-fit-4-1.hs'
----------------------------------------------------------------------------------
-- Dynamic programming solution to the knapsack (or, rather, disk) packing problem
--
-- Let the `bestDisk x' be the "most tightly packed" disk of total
-- size no more than `x'.
precomputeDisksFor :: [Dir] -> [DirPack]
precomputeDisksFor dirs =
      -- By calculating `bestDisk' for all possible disk sizes, we could
      -- obtain a solution for particular case by simple lookup in our list of
      -- solutions :)
  let precomp = map bestDisk [0..]

      -- How to calculate `bestDisk'? Lets opt for a recursive definition:
      -- Recursion base: best packed disk of size 0 is empty
      bestDisk 0 = DirPack 0 []
      -- Recursion step: for size `limit`, bigger than 0, best packed disk is
      -- computed as follows:
      bestDisk limit =
         -- 1. Take all non-empty dirs that could possibly fit to that disk by itself.
         --    Consider them one by one. Let the size of particular dir be `dir_size d'.
         --    Let's add it to the best-packed disk of size <= (limit - dir_size d), thus
         --    producing the disk of size <= limit. Lets do that for all "candidate"
         --    dirs that are not yet on our disk:
         case [ DirPack (dir_size d + s) (d:ds)
                | d <- filter ( inRange (1,limit).dir_size ) dirs
                  , dir_size d > 0
                  , let (DirPack s ds)=precomp!!fromInteger (limit - dir_size d)
                  , d `notElem` ds
              ] of
                -- We either fail to add any dirs (probably, because all of them too big).
                -- Well, just report that disk must be left empty:
                [] -> DirPack 0 []
                -- Or we produce some alternative packings. Let's choose the best of them all:
                packs -> maximumBy cmpSize packs

      cmpSize a b = compare (pack_size a) (pack_size b)

      in precomp

-- When we precomputed disk of all possible sizes for the given set of dirs, solution to
-- particular problem is simple: just take the solution for the required 'media_size' and
-- that's it!
-- Taken from 'cd-fit-4-3.hs'
dynamic_pack limit dirs = (precomputeDisksFor dirs)!!(fromInteger limit)


-- Taken from 'cd-fit-4-2.hs'
prop_dynamic_pack_is_fixpoint ds =
  let pack = dynamic_pack media_size ds
      in pack_size pack == pack_size (dynamic_pack media_size (dirs pack))

prop_dynamic_pack_small_disk ds =
  let pack = dynamic_pack 50000 ds
      in pack_size pack == pack_size (dynamic_pack 50000 (dirs pack))


-- rename "old" main to "moin"
main = quickCheck prop_dynamic_pack_small_disk
