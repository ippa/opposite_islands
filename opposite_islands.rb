#!/usr/bin/env ruby
#
# 1.1 - 2 small bugfixes
# - Move media into media/-dir
# - Better usage of autoload_dirs for flexibility where to put mediafiles without alot of extra code
# - Now enemy firing isn't eating Your points ;)
# - Unit selection was jumpy when a unit died, fixed
#
# 1.0 - initial release
# - initial release for rbweekend #2 
#
#
$: << "./lib"
$: << "../rubygame_ext/"
require 'rubygame'
include Rubygame
include Rubygame::Color

MEDIA_DIR = "media"
Surface.autoload_dirs = [ MEDIA_DIR ]
Sound.autoload_dirs = [ MEDIA_DIR ]

require 'game_objects'

SCREEN_WIDTH = 1000  
SCREEN_HEIGHT = 500
  
Rubygame.init()
queue = EventQueue.new()
queue.ignore = [MouseMotionEvent, ActiveEvent]
raise "SDL_gfx is not available. Bailing out."  if  ($gfx_ok = (VERSIONS[:sdl_gfx] == nil))

TTF.setup()
@font = TTF.new("#{MEDIA_DIR}/FreeSans.ttf",25)
@screen = Screen.set_mode([SCREEN_WIDTH, SCREEN_HEIGHT], 0, [HWSURFACE, DOUBLEBUF])
@screen.show_cursor = false

@background = Surface.autoload("background_sea.jpg")
@background.blit(@screen, [0, 0])
@screen.update

@enemy_planes = Sprites::Group.new
@enemy_bullets = Sprites::Group.new

@planes = Sprites::Group.new
@bullets = Sprites::Group.new

@points = 0
(1..4).each { |nr| @planes << SmallPlane.new(100 + nr*40, SCREEN_HEIGHT-50) }
(1..2).each { |nr| @planes << BigPlane.new(300 + nr*100, SCREEN_HEIGHT-40) }
(1..3).each { |nr| @planes << Helicopter.new(600 + nr*50, SCREEN_HEIGHT-40) }
[@bullets, @planes, @enemy_planes, @enemy_bullets].each { |object| object.extend(Sprites::UpdateGroup) }

# Create the clock (sprites starts to move right here) and start painting stuff
clock = Clock.new()
clock.target_framerate = 60
update_time, framerate = total_update_time = 0


def create_enemy(type = :small_plane)
  if type == :small_plane
    plane = SmallPlane.new(100 + rand(20)*50, 20 + rand(20)) 
  elsif type == :big_plane
    plane = BigPlane.new(100 + rand(7)*100, 20 + rand(10)) 
  elsif type == :helicopter
    plane = Helicopter.new(100 + rand(10)*80, 25 + rand(10)) 
  end
  plane.angle = Math::PI * 1.5
  @enemy_planes << plane
end
def activate_random_enemy
  enemy = random_grounded_enemy
  enemy.activate! unless enemy.nil?
end
def random_grounded_enemy
  @enemy_planes.find {|x| !x.active? }
end
def random_active_enemy
  @enemy_planes.find {|x| x.active? }
end

def realign_selected
  @planes.each_with_index do |plane, index|
    @selected = index if plane.selected?
  end
end

def current_object
  while @planes[@selected].nil?
    @selected += 1
    @selected = 0 if @selected >= @planes.size
    game_over if @planes.size == 0
  end
  @planes[@selected].select!
  @planes[@selected]
end
def next_object
  current_object.selected = false
  @selected += 1
  @selected = 0 if @selected >= @planes.size
  current_object.selected = true
  current_object
end
def prev_object
  current_object.selected = false
  @selected -= 1
  @selected = (@planes.size-1) if @selected < 0
  current_object.selected = true
  current_object
end

@selected = 0
@planes[@selected].selected = true
@left_shift = false

def game_over
  @font.render("Game Over! Score: #{@points}", true, Color[:red]).blit(@screen,[SCREEN_WIDTH/2,SCREEN_HEIGHT/2-200])
  @screen.update
  sleep 5
  exit
end


@frames_per_big_enemy_plane = 2000
@frames_per_small_enemy_plane = 700
@frames_per_enemy_helicopter = 1200
@frames_per_activate = 200
@frames_per_autofire = 100
@frames_per_move = 300
@frames_count = 0

#
# MAIN-LOOP STARTS HERE
#
loop do
  dirty_rects = []
	
  queue.each do |event|
    case event
      when KeyDownEvent
        case event.key
          when K_Q    then  create_enemy
          when K_W    then  activate_random_enemy
          when K_E    then  move_random_enemy
          when K_TAB    then  @left_shift ? prev_object : next_object
          when K_LSHIFT then  @left_shift = true
          when K_ESCAPE then  throw :rubygame_quit
          when K_LEFT   then  current_object.move_left
          when K_RIGHT  then  current_object.move_right
          when K_SPACE  then  current_object.active? ? current_object.toggle_autofire : current_object.activate!
      end
      when KeyUpEvent
        case event.key
          when K_LSHIFT then  @left_shift = false
          when K_LEFT   then  current_object.halt_left
          when K_RIGHT  then  current_object.halt_right
	      end
      when QuitEvent
        throw :rubygame_quit
    end
  end

  @planes.each do |plane|
    if plane.autofire == true && plane.frame_count > plane.frames_per_bullet
      @bullets << plane.fire
      @points -= 1
      plane.frame_count = 0
    end
  end
  
  @enemy_planes.each do |plane|
    if plane.autofire == true && plane.frame_count > plane.frames_per_bullet
      @enemy_bullets << plane.fire(Color[:black])
      plane.frame_count = 0
    end
  end
  
  #
  # Undraw -> Remove dead objects -> Update
  #
  [@planes, @enemy_planes, @bullets, @enemy_bullets].each do |sprite_group|
    sprite_group.undraw(@screen, @background)
    sprite_group.reject! { |b| b.status == :dead }
    realign_selected
    sprite_group.update(update_time)
  end
  
  #
  # Wrap objects that hits screenborder -> Draw
  #
  [@planes, @enemy_planes, @bullets, @enemy_bullets].each do |sprite_group|
    # All objects wrap around when they hit screenborder!
    sprite_group.each do |o|
      o.x = 0             if o.x > SCREEN_WIDTH
      o.x = SCREEN_WIDTH  if o.x < 0
      o.y = 0             if o.y > SCREEN_HEIGHT
      o.y = SCREEN_HEIGHT if o.y < 0
    end
    sprite_group.draw(@screen)
  end 
  
  #
  # Collide enemy bullets with our planes
  #
  @enemy_bullets.each do |bullet|
    @planes.each do |object|
      if object.active? && object.col_rect.collide_point?(bullet.x, bullet.y)
        bullet.die!
        if object.damage(10).dead?
          #object.undraw(@screen, @background)
          
          #if object.selected?
          #  @planes.reject! { |x| x.status == :dead }
         # 
          #  current_object.select!
          #  current_object.update_image
         # 
         #   next_object
         #   while current_object.nil?
         #     game_over if @planes.size == 0
         #     next_object
         #   end
          #  current_object.update_image
          #end
        end
      end
    end
  end
  
  @bullets.each do |bullet|
    @enemy_planes.each do |enemy|
      if enemy.active? && enemy.col_rect.collide_point?(bullet.x, bullet.y)
        if enemy.damage(10).dead?
          @points += enemy.value 
        end
        bullet.die!
      end
    end
  end
  
  @planes.each do |object|
    @enemy_planes.each do |enemy|
      if object.active? && enemy.active? && object.col_rect.collide_rect?(enemy.col_rect)
        object_health = object.health
        enemy_health = enemy.health
        object.damage(enemy_health)
        
        if enemy.damage(object_health).dead?
          @points += enemy.value 
        end
      end
    end
  end
 
  @points_rect = Rect.new(SCREEN_WIDTH-170, SCREEN_HEIGHT-60, SCREEN_WIDTH-100, SCREEN_HEIGHT-10)
  @background.blit(@screen, @points_rect, @points_rect)
  @font.render("Score: #{@points}", true, Color[:white]).blit(@screen,[SCREEN_WIDTH-150,SCREEN_HEIGHT-50])
  
  game_over if @planes.size == 0
  
  @screen.update  
  if framerate != clock.framerate
		framerate = clock.framerate
    if current_object
      @screen.title = "Opposite Island! [framerate: %d] [speed_x: %d, speed_y: %d, angle: %d, health: %d]" % [framerate, current_object.speed_x, current_object.speed_y, current_object.angle, current_object.health]
    end
    @frames_count += 1
  end
	update_time = clock.tick()


begin
  @per_scale = 0.95
  #
  # Ghetto-style gen of enemies
  # Goes on forever, pumping out enemies and toggling moves and autofire.. 
  # 
  if @frames_count % @frames_per_big_enemy_plane == 0
    create_enemy(:big_plane)
    @frames_per_big_enemy_plane = (@frames_per_big_enemy_plane * 0.99).to_i
  end
  if @frames_count % @frames_per_small_enemy_plane == 0
    create_enemy(:small_plane)
    @frames_per_small_enemy_plane = (@frames_per_small_enemy_plane * 0.99).to_i
  end
  if @frames_count % @frames_per_enemy_helicopter == 0
    create_enemy(:helicopter)
    @frames_per_enemy_helicopter = (@frames_per_enemy_helicopter * 0.99).to_i
  end
  if @frames_count % @frames_per_activate == 0
    if e = random_grounded_enemy
      e.activate!
      @frames_per_autofire = (@frames_per_autofire * @per_scale).to_i
    end
  end
  if @frames_count % @frames_per_autofire == 0
    if e = random_active_enemy
      e.autofire = true
      @frames_per_autofire = (@frames_per_autofire * @per_scale).to_i
    end
  end
  if @frames_count % @frames_per_move == 0
    if e = random_active_enemy
      #angle = rand(Math::PI*2)
      if rand(2) == 0
        e.angle -= (Math::PI*2)/10
      else
       e.angle += (Math::PI*2)/10
      end
      @frames_per_move = (@frames_per_move * @per_scale).to_i
    end
  end
rescue ZeroDivisionError
end

end

puts "Quitting!"
Rubygame.quit()