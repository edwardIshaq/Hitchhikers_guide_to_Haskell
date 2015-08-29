module Main where

main = do putStrLn "Whats your name?"
          name <- getLine
          putStrLn ("Greetings Sir " ++ name)
          putStrLn "Whats your favorite color ?"
          color <- getLine
          putStrLn ("Funny " ++ color ++ " is my favorite too " ++ name)
