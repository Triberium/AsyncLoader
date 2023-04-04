# Asynchronous Loader
This demonstration project implements an **Asynchronous Loader** for the [Godot Engine](https://godotengine.org)'s TileMap Node. It loads chunks of tiles for use in large pre-generated maps, where the developer might want to reduce load times and prevent crashes when it comes to loading whole maps all at once.

## TileMaps
The **Async Loader** uses a pre-generated map and groups up tiles into blocks. The blocks are then queued up into the *Loader*, which proceeds to draw the chunks of blocks in different frames to prevent lag and provide a seamless transition. The method itself is limiting as it only draws nearby blocks and as such any tile collision shapes outside of the loaded chunk may not be available for AI use.


## Free and Open Source
This project is provided free and open source under the MIT license. If you wish to read it, please take a look at the **LICENSE** file provided in this repo.