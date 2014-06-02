{-# LANGUAGE Rank2Types #-}
module Engine.Network.Client 
	(
	  consumeClientWorld
	, decodeSteps
	) where

import Engine.World
import Engine.Game

import Control.Monad.RWS.Strict

--import Control.Wire
import qualified Control.Wire as W

import qualified Data.ByteString as B
 
import Pipes as P
import Pipes.Concurrent
import Pipes.Binary
import qualified Engine.Input.Actions as A
import Engine.Render
import Control.Monad.State.Strict
import Engine.Render.Map
import Data.Tiled
import Control.Concurrent.STM ( TVar, readTVar, writeTVar)
import Control.Lens
import qualified Data.Map as Map
import qualified Data.Set as Set
import Engine.World.Objects
import Engine.World.Common
import Engine.Render.Update

type ProdDecoder a = (Monad m)	 
	=> Producer B.ByteString m r
	-> Producer' (ByteOffset, a) m (Either (DecodingError, Producer B.ByteString m r) r)


decodeSteps :: ProdDecoder ([(PlayerId, A.Action)], Rational)
decodeSteps = decodeMany



consumeClientWorld :: 
	  TVar RenderContext
	-> Game
	-> Consumer (ByteOffset, ([(Int, A.Action)], Rational)) IO r
consumeClientWorld renderContextVar game = do
	-- run wires
	(_, (actions, dt)) <- await

	let manager2 = worldManagerUpdate (game^.gameWorldManager) actions

	rc <- lift $ atomically $ do
		renderContext <- readTVar renderContextVar
		return renderContext

	let game' = game & gameRenderWorld .~ (rc^.rcWorldRenderContext.wrcWorld)

	let newGame = execState (do
			gameWorldManager .= manager2
			updateGame dt
		) game'

	--(w', (manager', delta)) <- lift $ clientStepWorld w world manager2 dt

	lift $ atomically $ do
		--renderContext <- readTVar renderContextVar
		writeTVar renderContextVar (rc 
				& rcWorldRenderContext.wrcWorld .~ (newGame^.gameRenderWorld)
			)

	--lift $ performGC

	consumeClientWorld renderContextVar newGame