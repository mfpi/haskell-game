{-# LANGUAGE TemplateHaskell, Arrows #-}
module Game.Game where

import Control.Lens
import Debug.Trace
import qualified Game.Render.World as R

import qualified Game.World.Common as G
import qualified Game.World.Objects as G
import qualified Game.World.Delta as G
import qualified Game.World as G
import qualified Game.Render.Update as U

import qualified Game.World.Gen as Gen
import qualified Game.World.Gen.Terrain as Gen

import qualified Game.World.Import.Tiled as T
import qualified Data.Tiled as T
import Game.World.Wires
import Game.World.Lens
import qualified Data.Set as Set
import qualified Data.Map as Map
import qualified Control.Wire as W
import qualified Control.Wire.Unsafe.Event as W

import Control.Monad.State
import Control.Monad.RWS

import Game.World.Common

import Control.Arrow

data Game = Game
	{ _gameName :: String
	, _gameTiled :: T.TiledMap
	, _gamePlayerStartPos :: (Float, Float)
	, _gameLogicWorld :: G.World
	, _gameRenderWorld :: R.World
	, _gameLastDelta :: G.WorldDelta
	, _gameWorldManager :: G.WorldManager
	, _gameRenderObjects :: [U.Renderable]
	, _gameWire :: G.WorldWire () ()
	, _gameGenMap :: Gen.GenMap
	}

newRenderConfig :: R.RenderConfig
newRenderConfig = execState (do
		-- players
		R.rcTiles . at "PlayerS1" .= Just ("sprite_klein3", 0)
		R.rcTiles . at "PlayerS2" .= Just ("sprite_klein3", 1)
		R.rcTiles . at "PlayerS3" .= Just ("sprite_klein3", 2)
		R.rcTiles . at "PlayerS4" .= Just ("sprite_klein3", 3)

		R.rcTiles . at "PlayerN1" .= Just ("sprite_klein3", 8)
		R.rcTiles . at "PlayerN2" .= Just ("sprite_klein3", 9)
		R.rcTiles . at "PlayerN3" .= Just ("sprite_klein3", 10)
		R.rcTiles . at "PlayerN4" .= Just ("sprite_klein3", 11)

		R.rcTiles . at "PlayerW1" .= Just ("sprite_klein3", 16)
		R.rcTiles . at "PlayerW2" .= Just ("sprite_klein3", 17)
		R.rcTiles . at "PlayerW3" .= Just ("sprite_klein3", 18)
		R.rcTiles . at "PlayerW4" .= Just ("sprite_klein3", 19)

		R.rcTiles . at "PlayerE1" .= Just ("sprite_klein3", 28)
		R.rcTiles . at "PlayerE2" .= Just ("sprite_klein3", 29)
		R.rcTiles . at "PlayerE3" .= Just ("sprite_klein3", 30)
		R.rcTiles . at "PlayerE4" .= Just ("sprite_klein3", 31)
	
		-- arrows
		R.rcTiles . at "ArrowW" .= Just ("arrow", 0)
		R.rcTiles . at "ArrowNW" .= Just ("arrow", 1)
		R.rcTiles . at "ArrowN" .= Just ("arrow", 2)
		R.rcTiles . at "ArrowNE" .= Just ("arrow", 3)
		R.rcTiles . at "ArrowE" .= Just ("arrow", 4)
		R.rcTiles . at "ArrowSE" .= Just ("arrow", 5)
		R.rcTiles . at "ArrowS" .= Just ("arrow", 6)
		R.rcTiles . at "ArrowSW" .= Just ("arrow", 7)

		R.rcTiles . at "WallW2" .= Just ("sewer_tileset", 8)
		R.rcTiles . at "WallS2" .= Just ("sewer_tileset", 9)
		R.rcTiles . at "WallE2" .= Just ("sewer_tileset", 10)

		-- duplicates
		R.rcTiles . at "WallSW2" .= Just ("sewer_tileset", 8)
		R.rcTiles . at "WallSE2" .= Just ("sewer_tileset", 10)

		R.rcTiles . at "WallSW1" .= Just ("sewer_tileset", 16)
		R.rcTiles . at "WallS1" .= Just ("sewer_tileset", 17)
		R.rcTiles . at "WallSE1" .= Just ("sewer_tileset", 18)

		R.rcTiles . at "WallN3" .= Just ("sewer_tileset", 4)
		R.rcTiles . at "WallNE3" .= Just ("sewer_tileset", 5)
		R.rcTiles . at "WallE3" .= Just ("sewer_tileset", 13)
		R.rcTiles . at "WallSE3" .= Just ("sewer_tileset", 21)
		R.rcTiles . at "WallS3" .= Just ("sewer_tileset", 1)
		R.rcTiles . at "WallSW3" .= Just ("sewer_tileset", 19)
		R.rcTiles . at "WallW3" .= Just ("sewer_tileset", 11)
		R.rcTiles . at "WallNW3" .= Just ("sewer_tileset", 3)
		R.rcTiles . at "WallCenter3" .= Just ("sewer_tileset", 12)

		R.rcTiles . at "WallOuterNW3" .= Just ("sewer_tileset", 6)
		R.rcTiles . at "WallOuterNE3" .= Just ("sewer_tileset", 7)
		R.rcTiles . at "WallOuterSW3" .= Just ("sewer_tileset", 22)
		R.rcTiles . at "WallOuterSE3" .= Just ("sewer_tileset", 23)

		R.rcTiles . at "FinalFloor" .= Just ("sewer_tileset", 33)
		R.rcTiles . at "NoMatch" .= Just ("sewer_tileset", 40)
		R.rcTiles . at "Wall" .= Just ("sewer_tileset", 41)

	) $ R.RenderConfig {} & R.rcTiles .~ Map.empty

makeLenses ''Game

newGame :: String -> IO Game
newGame name = do
	tiledMap <- T.tMap
	let genMap = Gen.mkGenWorld
	(oldWorld, newWorld, delta, manager) <- mkGameWorld tiledMap (50, -200) genMap
	print delta 
	let renderWorld = mkRenderWorld tiledMap delta genMap
	let (newRenderWorld, newRenderables) = 
		updateRender delta oldWorld newWorld renderWorld []
	let game = Game
		{ _gameName = name
		, _gameTiled = tiledMap
		, _gamePlayerStartPos = (50, -200)
		, _gameLogicWorld = newWorld
		, _gameLastDelta = delta
		, _gameWorldManager = manager
		, _gameRenderWorld = newRenderWorld
		, _gameRenderObjects = newRenderables
		, _gameWire = G.testwire
		, _gameGenMap = genMap
		}
	return game

gameStepWorld :: 
	   WorldWire () b 
	-> World 
	-> WorldManager 
	-> Rational 
	-> (WorldWire () b, (WorldManager, WorldDelta))
gameStepWorld w' world' state' dt' = (w, (worldManager, worldDelta))
	where
		dt = W.Timed (fromRational dt') ()
	-- run wires
		(w, worldManager, worldDelta) = runRWS (do
				(mx, newWire) <- W.stepWire w' dt (Right ())
				return newWire
			) world' state'

--updateRender :: G.WorldDelta -> G.World -> G.World -> R.World -> (R.World, [U.Renderable])
updateRender delta oldWorld newWorld renderWorld renderablesIn = (renderWorld3, newRenderablesDeleted ++ newRenderables)
	where
		-- remove objects from renderer
		(_, renderWorld2', removeRenderables) = runRWS (do
				U.removeRenderObjects
			) (oldWorld, delta, renderablesIn) renderWorld

		newRenderablesDeleted = Set.toList $ Set.difference (Set.fromList renderablesIn) (Set.fromList removeRenderables)

		-- add objects to renderer
		(_, renderWorld2, newRenderables) = runRWS (do
				--updateTiled
				U.newRenderObjects
			) (newWorld, delta, newRenderablesDeleted) renderWorld2'

		-- update render objects
		(_, renderWorld3, _) = runRWS U.update
			(newWorld, delta, newRenderablesDeleted ++ newRenderables) renderWorld2

updateGame :: Rational -> State Game ()
updateGame dt = do
	game <- get
	renderablesIn <- use $ gameRenderObjects
	world <- use $ gameLogicWorld
	worldWire <- use $ gameWire
	oldManager <- use $ gameWorldManager
	renderWorld <- use $ gameRenderWorld

	let (newWire, (newManager, newDelta)) = gameStepWorld worldWire world oldManager dt
	let newWorld = G.applyDelta world newDelta
	let (newRenderWorld, newRenderables) = updateRender newDelta world newWorld renderWorld renderablesIn

	gameRenderObjects .= newRenderables
	gameRenderWorld .= newRenderWorld
	gameLogicWorld .= newWorld
	gameLastDelta .= newDelta
	gameWorldManager .= newManager
	gameWire .= newWire

	return ()

mkRenderWorld :: T.TiledMap -> G.WorldDelta -> Gen.GenMap -> R.World
mkRenderWorld tiledMap delta genMap = nWorld
	where	
		renderWorld = R.loadMapFromTiled tiledMap
			& R.wRenderConfig .~ newRenderConfig

		nWorld = 
			traceShow (renderWorld^.R.wRenderConfig) $
			R.wUpdate (do
				R.wLayer "BottomLayer" .= (Just $ R.newLayer R.TileLayerType)
				R.wLayer "ObjectLayer" .= (Just $ R.newLayer R.ObjectLayerType)
				R.wLayer "TopLayer" .= (Just $ R.newLayer R.TileLayerType)

				mapM_ (\((x, y), tileType) -> do
						tile <- use $ R.wTile (show tileType) -- TODO: change show to getter
						-- top tiles are transparent so we need a floor tile beneath them
						if (Gen.tileLayer genMap (x, y)) == "TopLayer"
							then  do
								floorTile <- use $ R.wTile "FinalFloor"
								R.wLayerTile "BottomLayer" (x, -y) .= (Just floorTile)
							else return ()
						R.wLayerTile (Gen.tileLayer genMap (x, y)) (x, -y) .= (Just tile)
					) (Map.toList $ genMap^.Gen.mapCompiledCells)

			) renderWorld

--mkGameWorld :: Game -> IO (G.World, Delta, WorldManager)
mkGameWorld tiledMap startPos genMap = do
	let (worldManager, worldDelta) = execRWS (
			W.stepWire initWire (W.Timed 0 ()) (Right ())
		) world G.emptyWM

	let world' = G.applyDelta world worldDelta
	return (world, world', worldDelta, worldManager)


	where
		wallBoundaries = Gen.tileBoundaries genMap
		world = G.emptyW 
			{ _wTileBoundary = tiledMap^.T.mapTileSize
			}

		initWalls [] = proc input -> do
			returnA -< ()
		initWalls (((ox, oy), (px, py)):wallsData) = proc input -> do

			wallsId <- spawnObjectAt "Wall" (ox, -oy) -< input
			_ <- wLiftSetOnce setBoundary (
					[ (0, 0)
					, (0, py - oy)
					, (px - ox, py - oy)
					, (px - ox, 0)]
				) -< wallsId
			_ <- wLiftSetOnceVoid setStaticCollidable -< wallsId

			_ <- initWalls wallsData -< input
			returnA -< ()

		initWire = proc input -> do
			p1Id <- spawnObjectAt "Player1" startPos -< input
			p2Id <- spawnObjectAt "Player2" (120, 50) -< input

			_ <- animate (G.objectAnimation 1 G.South) -< p1Id
			_ <- animate (G.objectAnimation 2 G.South) -< p2Id

			_ <- wLiftSetOnce setBoundary G.playerBoundary -< p1Id
			_ <- wLiftSetOnce setBoundary G.playerBoundary -< p2Id

			_ <- initWalls wallBoundaries -< input

			returnA -< ()

mkUIWorld :: Game -> R.World
mkUIWorld game = nWorld
	where	
		tiledMap = game^.gameTiled
		renderWorld = R.loadMapFromTiled tiledMap
		nWorld = R.wUpdate (do
				Just tsId <- use $ R.mapHashes.R.gameTilesets.at "heart"
				R.wObject "PlayerHealth" .= (Just $ R.newObject tsId 0)
				Just objId <- use $ R.mapHashes.R.gameObjects.at "PlayerHealth"
				R.wLayer "ObjectLayer" .= (Just $ R.newLayer R.ObjectLayerType)
				R.wLayerObject "ObjectLayer" "PlayerHealth" 
					.= (Just $ R.newRenderObject objId (10, -10) 0)
			) renderWorld