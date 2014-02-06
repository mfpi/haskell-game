{-# LANGUAGE TemplateHaskell #-}
module Game.Render where

import Graphics.Rendering.OpenGL
--import Graphics.Rendering.OpenGL.Texturing.Filter
import qualified Graphics.Rendering.OpenGL as GL
--import Graphics.Rendering.OpenGL (($=))
import qualified Graphics.UI.GLFW as GLFW

import qualified Data.Vector.Storable as V
import Foreign.Storable
import Foreign.Ptr
import Data.Int

import Game.Render.Map
import Game.Render.Render
import Game.Render.Camera
import Codec.Picture.Png
import Codec.Picture

import System.Exit
import Control.Lens

data RenderContext = RenderContext
	{ _rcMainProgram :: Program
	, _rcWorldRenderContext :: WorldRenderContext
	--, _rcDebugBuffer :: GL.BufferObject
	--, rcCamera :: Camera
	}
makeLenses ''RenderContext

newRenderContext renderMap = do

--	if blend {
--gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
--gl.Enable(gl.BLEND)
--} else {
--gl.Disable(gl.BLEND)
--gl.BlendFunc(gl.ONE, gl.ZERO)
--}
	GL.blendFunc $= (GL.SrcAlpha, GL.OneMinusSrcAlpha)
	GL.blend $= GL.Enabled

	program <- setupShaders

	wrc <- newWorldRenderContext renderMap
	bindWorldRenderContext wrc program

	--[debugBuffer] <- GL.genObjectNames 1 :: IO [GL.BufferObject]

	--uploadFromVec GL.ShaderStorageBuffer debugBuffer (V.fromList [i | i <- [0..4*6*81-1]] :: V.Vector Int32)

	return RenderContext
		{ _rcMainProgram = program
		, _rcWorldRenderContext = wrc
		--, _rcDebugBuffer = debugBuffer
		}

clearWindow window = do
	GL.clearColor $= GL.Color4 1 1 1 1
	GL.clear [GL.ColorBuffer]
	(width, height) <- GLFW.getFramebufferSize window
	GL.viewport $= (GL.Position 0 0, GL.Size (fromIntegral width) (fromIntegral height))

render window rc cam = do
	-- update camera in every frame for now
	(width, height) <- GLFW.getFramebufferSize window
	clearWindow window

	GL.currentProgram $= Just (rc^.rcMainProgram)

	programSetViewProjection (rc^.rcMainProgram) cam
	--getShaderStorageBlockIndex (rcMainProgram rc) "Debug" >>= print
	--getShaderStorageBlockIndex (rcMainProgram rc) "Pos" >>= print
	--getShaderStorageBlockIndex (rcMainProgram rc) "ObjectData" >>= print
	--getShaderStorageBlockIndex (rcMainProgram rc) "TileSets" >>= print

	--getUniformBlockIndex (rc^.rcMainProgram) "Debug" >>= print
	--getUniformBlockIndex (rc^.rcMainProgram rc) "Pos" >>= print
	--getUniformBlockIndex (rcMainProgram rc) "ObjectData" >>= print
	--getUniformBlockIndex (rcMainProgram rc) "TileSets" >>= print


	--debugIndex <- getShaderStorageBlockIndex (rcMainProgram rc) "Debug"
	--print $ "Debug index" ++ show debugIndex
	--GL.bindBufferBase' GL.ShaderStorageBuffer debugIndex (rcDebugBuffer rc)
	--GL.shaderStorageBlockBinding (rcMainProgram rc) debugIndex debugIndex

	updateWorldRenderContext (rc^.rcWorldRenderContext)
	renderWorldRenderContext (rc^.rcMainProgram) (rc^.rcWorldRenderContext)

	--errors <- GL.get GL.errors
	--print $ errors
	--GL.bindBuffer GL.ShaderStorageBuffer $= Just (rcDebugBuffer rc)
	--GL.withMappedBuffer (GL.ShaderStorageBuffer) GL.ReadOnly printPtr failure

	--where
	--	printPtr :: Ptr Int32 -> IO [()]
	--	printPtr ptr = sequence [
	--		peekElemOff ptr idx >>= \x -> print ("Debug" ++ show x)  | idx <- [0..4]
	--		]

	--	failure GL.MappingFailed = print "Mapping failed" >> return []
	--	failure GL.UnmappingFailed = print "Unmapping failed" >> return []
