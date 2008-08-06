module RubygameExtension
  module Base
    #def call_extension_methods(method)
    #  p self.included_methods
    #end
  end
  
  module OnScreen
    # is the sprite inside the screen, usefull to know when drawing objects.
    def inside_screen?(x = @x, y = @y)
      x >= 0 && x <= SCREEN_WIDTH && y >= 0 && y <= SCREEN_HEIGHT
    end
  end
  
  #
  # Modifies: @health, @lives, @status
  #
  module Alive
    def damage(punch)
      @health = 0 if @health.nil? ## ugly fix for something :/
      
      @health -= punch
      if  @health <= 0
        @health = 0
        die!
      end
      self
    end
		
    def die!
      @lives -= 1 if defined?(@lives)
      @status = :dead
      self
    end
    
    def dead?
      @status == :dead
    end
  end

  module Movement
    module XYMovement
  
      def self.included(base)
        @x = 0.0
        @y = 0.0
      end
      
      def xy_movement_update(time)
        base = time/100.0
        
        @x += @speed_x.to_f * base
        @y += @speed_y.to_f * base
        
        @rect.centerx = @x.to_i
        @rect.centery = @y.to_i
        
        if defined?(@col_rect)
          @col_rect.centerx = @rect.centerx
          @col_rect.centery = @rect.centery
        end
      end
    end
  end
end