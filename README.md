# Game integration

This repo contains the third-party integrations we've created for our partner games.

## Cubzh
*  [Cubzh](https://cu.bzh/) is a super lightweight Roblox-like game that uses voxels.
*  Although [the platform itself](https://github.com/cubzh/cubzh) is coded in C, each game is scriptable with Lua.
*  We're adding in this repo's `./cubzh` folder, the Lua scripts we've built to create game demos. The first demo's script is `./cubzh/cubzh.lua` - it's a maze runner game where the player has to craft weapons to defeat a sequence of enemies. The crafting mechanic relies on a call to a pixel-art diffusion model that creates an image for the given prompt. Under the hood, we call our API to resolve the encounter between the weapon and the current enemy.
*  In the future, we'll add a `./cubzh/modules` sub-folder containing Lua modules we've managed to include inside the game.

   
