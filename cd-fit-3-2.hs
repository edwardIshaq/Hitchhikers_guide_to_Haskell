module Main where
import Data.List (sortBy)
import Text.ParserCombinators.Parsec
import Test.QuickCheck
import Control.Monad (liftM2, replicateM)

-- parseInput parses output of "du -sb", which consists of many lines,
-- ON MAC:  du -h 1  ~/Downloads
-- each of which describes single directory
parseInput =
  do dirs <- many dirAndSize
     eof :: Parser ()
     return dirs


-- Datatype Dir holds information about single directory - its size and name
data Dir = Dir {dir_size::Int, dir_name::String} deriving Show

instance Eq Dir where
   (==) dirA dirB = (dir_size dirA == dir_size dirB) && (dir_name dirA == dir_name dirB)

-- DirPack holds a set of directories which are to be stored on single CD.
-- 'pack_size' could be calculated, but we will store it separately to reduce
-- amount of calculation
data DirPack = DirPack {pack_size::Int, dirs::[Dir]} deriving Show

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

main = do input <- getContents
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
