#!/usr/bin/env ruby
$: << "../rubygame_ext/"
require 'rubygame'
#require 'rectext'
require 'movement'
include Rubygame

class Bullet
  include Sprites::Sprite
  include RubygameExtension::OnScreen
  
  attr_accessor :angle, :speed_x, :speed_y, :x, :y
  attr_reader :status

  @@sound = Sound.autoload("bullet.wav")
  @@sound.volume = 0.4
  
  def initialize(x, y, angle, range = 10, color = Color[:white])
    super()
    @x = x
    @y = y
    @angle = angle
    @status = :default
    @range = range
    @distance = 0
    @color = color
    
    @@sound.play
  end
  
  def update(time)
    base = time/100.0
    move_x = @speed_x.to_f * base
    move_y = @speed_y.to_f * base
    @x += move_x
    @y += move_y
    
    # kill bullets after X amount of frames
    @distance += 1
    die!  if @distance > @range
  end
  
  def die!
    @status = :dead
  end
  
  def inside_screen?(x = @x, y = @y)
    x >= 1 && x <= SCREEN_WIDTH-1 && y >= 1 && y <= SCREEN_HEIGHT-1
  end
  
  def draw(surface)
    if inside_screen?
      surface.set_at([@x.to_i, @y.to_i], @color)
      surface.set_at([(@x+1).to_i, @y.to_i], @color)
      surface.set_at([(@x+1).to_i, (@y+1).to_i], @color)
      surface.set_at([@x.to_i, (@y+1).to_i], @color)
    end
  end
  
  def undraw(surface, background)
    if inside_screen?
      surface.set_at([@x.to_i, @y.to_i], background.get_at(@x.to_i, @y.to_i) )
      surface.set_at([(@x+1).to_i, @y.to_i], background.get_at((@x+1).to_i, @y.to_i) )
      surface.set_at([(@x+1).to_i, (@y+1).to_i], background.get_at((@x+1).to_i, (@y+1).to_i) )
      surface.set_at([@x.to_i, (@y+1).to_i], background.get_at(@x.to_i, (@y+1).to_i) )
    end
  end
  
end

class FlyingObject
  include Sprites::Sprite
  include RubygameExtension::Base
  include RubygameExtension::Alive      # provides @health, @lives, die(), damage()
  include RubygameExtension::OnScreen   # provides inside_screen?()
  include RubygameExtension::Movement::XYMovement # provides X,Y movement update logic from @speed_x and @speed_y
  
  attr_accessor :animation, :status, :health, :angle
  attr_reader :speed_x, :speed_y, :status, :punch, :value
  attr_accessor :rect, :x, :y, :speed, :selected, :frame_count, :frames_per_bullet, :autofire

  def initialize(x, y)
		super()    
    @rect = Rect.new(x,y,*@image.size)
    @col_rect = @rect.dup
    
    @x, @y = x, y
		@speed_x = @speed_y = 0.0
		@status = :default
    
    @active = false  
    @selected = false
    
    @total_time = 0
    @angle = Math::PI / 2
    @angle_speed = 0.0
    
    @autofire = false
    @frame_count = 0
    
    xy_movement_update(100)
		update_image(1000)
	end
  
  def toggle_autofire
    if @autofire == true
      @autofire = false
    elsif @autofire == false
      @autofire = true  
    end
  end

  def selected?
    @selected
  end
  def select!
    @selected = true
  end
  
  def active?
    @active
  end

  def die!
    super
    @sound.stop
  end
  
  def activate!
    @angle_speed = 0 
    @active = true
    @sound.play( :fade_in => 1, :repeats => -1);
  end
    
	def move_left
    @angle_speed = @angle_speed_step
  end
  def move_right
    @angle_speed = -@angle_speed_step
	end
	def halt_left
    @angle_speed = 0  if @angle_speed > 0
  end
  def halt_right
    @angle_speed = 0  if @angle_speed < 0
	end

	def fire(color = Color[:white])
    bullet = Bullet.new(@x, @y, @angle, @bullet_range, color)
		bullet.speed_x = @speed_x * @bullet_speed
		bullet.speed_y = @speed_y * @bullet_speed
    
		@action = :fire
		bullet
  end
	
	def update(time)
    if @active
      @angle += @angle_speed
      @speed_x = @engine_power * Math.cos(@angle)
      @speed_y = -(@engine_power * Math.sin(@angle))
    
      xy_movement_update(time)
      @frame_count += 1
    end
    update_image(time)
  end
	
	def update_image(time = 0)
    @image = @source_image.rotozoom((@angle * 180.0/Math::PI)-90, [1,1], true)
    #@image.set_colorkey(Color[:black])
    old_center = @rect.center
    @rect.size = @image.size
    @rect.center = old_center
    @image.draw_circle_s([@image.width/2, @image.height/2], 3, Color[:red]) if @selected
  end
  
end

class SmallPlane < FlyingObject
  def initialize(x, y)
    @image = Surface.autoload("small_plane.png")
    @source_image = Surface.autoload("small_plane.png")
    super(x, y)
    
    @health = 40
    @value = 40
    @engine_power = 8
    @angle_speed_step = 0.05
    @bullet_speed = 5
    @bullet_range = 150
    @col_rect.inflate(-20,-20)
    @frames_per_bullet = 30
    
    @sound = Sound.autoload("plane_loop.wav")
    @sound.volume = 0.1
  end
end

class BigPlane < FlyingObject
  def initialize(x, y)
    @image = Surface.autoload("big_plane.png")
    @source_image = Surface.autoload("big_plane.png")    
    super(x, y)
    
    @health = 100
    @value = 100
    @engine_power = 3
    @angle_speed_step = 0.02
    @bullet_speed = 2
    @bullet_range = 800
    @col_rect.inflate(-20,-20)
    @frames_per_bullet = 30
    
    @sound = Sound.autoload("big_plane_loop.wav")
    @sound.volume = 0.3
  end
  
end

class Helicopter < FlyingObject
  def initialize(x, y)
    @image = Surface.autoload("helicopter.png")
    @source_image = Surface.autoload("helicopter.png")    
    super(x, y)
    
    @health = 20
    @value = 20
    @engine_power = 4
    @angle_speed_step = 0.07
    @bullet_speed = 4
    @bullet_range = 100
    @col_rect.inflate(-10,-10)
    @frames_per_bullet = 30
    
    @sound = Sound.autoload("helicopter_loop.wav")
    @sound.volume = 0.3
  end
end
