{-# OPTIONS_HADDOCK prune, not-home #-}

-- | Provides a rather raw interface to the websocket events
--   through a real-time Chan
module Discord.Gateway
  ( Gateway(..)
  , GatewayException(..)
  , startShardedGatewayThread
  , module Discord.Types
  ) where

import Prelude hiding (log)
import Control.Concurrent.Chan (newChan, dupChan, Chan)
import Control.Concurrent (forkIO, ThreadId, MVar)

import Discord.Types (Auth, Event, GatewaySendable)
import Discord.Gateway.EventLoop (connectionLoopWithShard, GatewayException(..))
import Discord.Gateway.Cache

-- | Concurrency primitives that make up the gateway. Build a higher
--   level interface over these
data Gateway = Gateway
  { _events :: Chan (Either GatewayException Event)
  , _cache :: MVar (Either GatewayException Cache)
  , _gatewayCommands :: Chan GatewaySendable
  }

-- | Create a Chan for websockets. This creates a thread that
--   writes all the received Events to the Chan. Accepts a tuple
--   representing the shard parameter to send in Identify.
startShardedGatewayThread :: (Int, Int) -> Auth -> Chan String -> IO (Gateway, ThreadId)
startShardedGatewayThread shard auth log = do
  eventsWrite <- newChan
  eventsCache <- dupChan eventsWrite
  sends <- newChan
  cache <- emptyCache :: IO (MVar (Either GatewayException Cache))
  tid <- forkIO $ connectionLoopWithShard shard auth eventsWrite sends log
  cacheAddEventLoopFork cache eventsCache log
  pure (Gateway eventsWrite cache sends, tid)
