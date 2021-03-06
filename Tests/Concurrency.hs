{-# LANGUAGE CPP, ForeignFunctionInterface #-}
module Tests.Concurrency where

#ifdef __HASTE__
import Haste
import Haste.Concurrent

foreign import ccall "sleep" sleep_ :: Int -> IO ()

output :: String -> CIO ()
output = liftIO . alert

#else
import Control.Concurrent
output = putStrLn
concurrent = id
#endif

runTest :: IO ()
runTest = do
  v <- newMVar (0 :: Int)
  concurrent $ forkIO $ do
    putMVar v 42
    output "wrote 42"
    output "derp"
  concurrent $ do
    x <- takeMVar v
    output ("got " ++ show x)
  v2 <- newEmptyMVar
  concurrent $ do
    forkIO $ do
      putMVar v2 "omg concurrency!"
      putMVar v2 "still concurrent"
      putMVar v2 "bye!"
    takeMVar v2 >>= output
    takeMVar v2 >>= output
    takeMVar v2 >>= output
