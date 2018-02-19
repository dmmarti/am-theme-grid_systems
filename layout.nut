///////////////////////////////////////////////////
//
// Attract-Mode Frontend - Grid layout
//
///////////////////////////////////////////////////
class UserConfig </ help="Navigation controls: Up/Down (to move up and down) and Page Up/Page Down (to move left and right)" />{

      </ label="Red (R) (0-255) Color", help="Value of red component for theme color", order=1 />
	  red = 147;
	  
      </ label="Green (G) (0-255) Color", help="Value of green component for theme color", order=2 />
	  green = 3;
	  
      </ label="Blue (B) (0-255) Color", help="Value of blue component for theme color", order=3 />
	  blue = 3;
	  
      </ label="Background Artwork", help="Select Background Artwork", options="image", order=4 />
	  select_bgArt = "image";
	  
      </ label="Grid Artwork", help="The artwork to display in the grid", options="boxart,snap,wheel", order=5 />
	  art = "boxart";

      </ label="Enable Idle Time", help="Activate or deactivate the idle timer", options="True,False", order=6 />
	  useidle = "True";
	  
      </ label="Idle Timeout", help="If no selection is made in this many seconds, then automatically go back to home menu", order=7 />
	  rtime = 300;
	  
      </ label="Transition Time", help="The amount of time (in milliseconds) that it takes to scroll to another grid entry", order=8 />
	  ttime = "50";	  
}

fe.load_module("conveyor");
fe.load_module("animate");

fe.layout.width = 1280;
fe.layout.height = 720;
fe.layout.preserve_aspect_ratio = true;

local my_config = fe.get_config();
local rows = 2;
local cols = 4;
local height = ( fe.layout.height * 11 / 12 ) / rows.tofloat();
local width = fe.layout.width / cols.tofloat();
local vert_flow = true;

// Convert user-supplied values to integers (because one might enter "cow" or
// anything, really, for a value, we need to sanitize by assuming positive 0).
local bgRed = abs(("0"+my_config["red"]).tointeger()) % 255;
local bgGreen = abs(("0"+my_config["green"]).tointeger()) % 255;
local bgBlue = abs(("0"+my_config["blue"]).tointeger()) % 255;
local user_interval = abs(("0"+my_config["rtime"]).tointeger());
local idle_enabled = my_config["useidle"] == "True";
local selsound_enabled = true;

local count = user_interval;
local last_time = 0;

local bgArt;
if ( my_config["select_bgArt"] == "image" ){
	bgArt = fe.add_image("bg.jpg", 0, 0, 1280, 720 );
} else if ( my_config["select_bgArt"] == "video" ){
	bgArt = fe.add_image("bg.mp4", 0, 0, 1280, 720 );
} else if ( my_config["select_bgArt"] == "snap" ){
	bgArt = fe.add_artwork("snap", 0, 0, 1280, 720 );
	bgArt.video_flags = Vid.NoAudio;
	bgArt.trigger = Transition.EndNavigation;
}
animation.add( PropertyAnimation( bgArt, {when = Transition.ToNewList, property = "alpha", start = 0, end = 255, time = 500}));

local scanline = fe.add_artwork("scanline.png", 0, 0, 1280, 720 );

local topBar = fe.add_image("white.png",0, 0, 1280, 25 )
topBar.set_rgb( bgRed, bgGreen, bgBlue );

local bottomBar = fe.add_image("white.png",0, 680, 1280, 39 )
bottomBar.set_rgb( bgRed, bgGreen, bgBlue );

local bottomBarBlack = fe.add_image("white.png", 175, 682, 930, 34 )
bottomBarBlack.set_rgb( 0, 0, 0 );

const PAD=4;


function nameyear(offset) {
	local name = fe.game_info(Info.Title, offset);
	local year = fe.game_info(Info.Year, offset);
	if ((name.len() > 0) && (year.len() > 0))
		return name + " (" + year + ")";
	return name;
}


class Grid extends Conveyor
{
	snap_t=null;
	frame=null;
	name_t=null;	
	sel_x=0;
	sel_y=0;
	listB=null;
	list=null;
    
    	ui_counter=null;
    	ui_time=null;
    	ui_banner=null;
    	ui_displayname=null;
    	ui_filter_a=null;
    	ui_filter_b=null;   
    	ui_filters=[];
    
	constructor()
	{
		base.constructor();

		sel_x = cols / 2;
		sel_y = rows / 2;
		stride = fe.layout.page_size = vert_flow ? rows : cols;
	
		try {
            transition_ms = my_config["ttime"].tointeger();
		} catch (e) {
			transition_ms = 220;
		}        
	}
    
    function create_layout(slots)
    {
	//Create list		
        set_slots(slots, get_sel()); //set grid slots

	//Setup Art
//        snap_t = fe.add_artwork("snap", 700, 55, 300, 300);
        snap_t = fe.add_image("frame.png", 700, 55, 300, 300);
	snap_t.trigger = Transition.EndNavigation;

        frame = fe.add_image("frame.png", width * 2, height * 2, width - 6, height - 17);

        name_t = fe.add_text("[!nameyear]", 190, 677, 900, 35);
        name_t.font = "SF Atarian System Bold";
        name_t.set_rgb( 220, 220, 220 );

        ui_banner = fe.add_image("banner.png", -300, 65, 280, 70);

        listB = fe.add_text("[ListEntry]/[ListSize]", -381, 81, 300, 50);
        listB.set_rgb(238, 236, 0);
        listB.font = "arctik 5";
        listB.align = Align.Left;
        listB.set_rgb(0, 0, 0);

        list = fe.add_text("[ListEntry]/[ListSize]", -380, 80, 300, 50);
        list.set_rgb(238, 236, 0);
        list.font = "arctik 5";
        list.align = Align.Left;

        local topBarLine = fe.add_image("white.png", 0, 25, 1280, 1);
        topBarLine.set_rgb(160, 160, 160);
        
		if (idle_enabled)
			ui_time = fe.add_image("time.png", 1380, 26, 110, 25);
      
        ui_displayname = fe.add_image ("systems/splash.png",-305, 67, 90, 67 );
        ui_displayname.preserve_aspect_ratio = true;

        ui_filter_b = fe.add_text("[FilterName] Games", -305, 66, 400, 25);
        ui_filter_b.align = Align.Left;
        ui_filter_b.font="arctik 5";
        ui_filter_b.set_rgb( 0, 0, 0 );

        ui_filter_a = fe.add_text("[FilterName] Games", -305, 65, 400, 25);
        ui_filter_a.align = Align.Left;
        ui_filter_a.font="arctik 5";        
        
		if (idle_enabled) {
			ui_counter = fe.add_text(count, 1420, 24, 100, 25);
			ui_counter.align = Align.Left;
			ui_counter.set_rgb(30, 30, 30);
			ui_counter.font = "archivonarrow-bolditalic";
		}
		
        // Filters        
        for ( local i = 0; i < fe.filters.len(); i++ ) {
            local filter = fe.filters[i];
            local shortname = filter.name.toupper();
            local offset = 70 * i;
            
            switch(filter.name) {
                //prefer known abbreviations
                case "Shooting":
                    shortname = "STG";
                    break;
                case "Sports":
                    shortname = "SPT";
                    break;

                //grab the first three letters as the short name
                default:
					if (shortname.len() > 3)
						shortname = shortname.slice(0, 3);
                    break;
            }
            
            fe.add_image("fb.png", -11 + offset, 26, 80, 32);            
            local newfilt = fe.add_text(shortname, -18 + offset, 30, 73, 18);
            newfilt.font="arctik 5";
            newfilt.set_rgb( 240, 240, 240 );
            if (i == fe.list.filter_index)
                newfilt.set_rgb( 212, 165, 33 );
            ui_filters.push(newfilt);
        }

        local statusmsg = fe.add_text("[DisplayName]", 140, -10, 1000, 30);
        statusmsg.font="futureforces";
        
        ::OBJECTS <- {
            msg = statusmsg,
            arrowL = fe.add_image("arrowL.png", 140, 687, 25, 25),
            arrowR = fe.add_image("arrowR.png", 1115, 687, 25, 25),
        }
        
		//Setup animations
		local move_banner = {when = Transition.ToNewList, property = "x", start = -480, end = 0, time = 800};
		local move_filter = {when = Transition.ToNewList, property = "x", start = -400, end = 91, time = 800};
		local move_filter2 = {when = Transition.ToNewList, property = "x", start = -400, end = 92, time = 800};
		local move_list   = {when = Transition.ToNewList, property = "x", start = -420, end = 78, time = 800};
		local move_list2   = {when = Transition.ToNewList, property = "x", start = -420, end = 79, time = 800};	
		
		animation.add( PropertyAnimation( ui_banner, move_banner ) );
		animation.add( PropertyAnimation( listB, move_list2 ) );
		animation.add( PropertyAnimation( list, move_list ) );
		if (idle_enabled) {
			animation.add( PropertyAnimation( ui_time,    {when = Transition.ToNewList, property = "x", start = 1380, end = 1180, time = 700}));	
			animation.add( PropertyAnimation( ui_counter, {when = Transition.ToNewList, property = "x", start = 1380, end = 1220, time = 700}));
		}
		animation.add( PropertyAnimation( ui_filter_b, move_filter2 ) );
		animation.add( PropertyAnimation( ui_filter_a, move_filter ) );
		animation.add( PropertyAnimation( ui_displayname, move_banner ) );
		animation.add( PropertyAnimation( OBJECTS.msg,    {when = Transition.ToNewList, property = "alpha", start = 10, end = 255, time = 1200, tween = Tween.Linear, pulse = true}));
		animation.add( PropertyAnimation( OBJECTS.arrowL, {when = Transition.ToNewList, property = "x", start = 130, end = 140, time = 600, loop = true}));
		animation.add( PropertyAnimation( OBJECTS.arrowR, {when = Transition.ToNewList,	property = "x",	start = 1125, end = 1115, time = 600, loop = true}));
		animation.add( PropertyAnimation( name_t,         {when = Transition.EndNavigation, property = "y", start = 707, end = 677, time = 80}));
		animation.add( PropertyAnimation( name_t,         {when = Transition.EndNavigation, property = "alpha", start = 0, end = 255, time = 100}));		
		
		//Render & Setup Events
       		update_frame(false);
		fe.add_signal_handler(this, "on_signal");
		if (idle_enabled)
			fe.add_ticks_callback(this, "on_tick");        
    }
	
	function update_frame(audio=true)
	{
		snap_t.x = width * sel_x + 10;
		snap_t.y = fe.layout.height / 19 + height * sel_y;

		frame.x = width * sel_x + 3;
		frame.y = fe.layout.height / 23 + height * sel_y;

		local newoffset = get_sel() - selection_index;	
		bgArt.index_offset = newoffset;
		snap_t.index_offset = newoffset;
		name_t.index_offset = newoffset;
		listB.index_offset = newoffset;
		list.index_offset = newoffset;
		
        //reset timeout
		if (idle_enabled) {
			count = user_interval;
			ui_counter.msg = count;
		}
    }

	function move_sound() {
			local selectMusic = fe.add_sound("select.mp3");
			selectMusic.playing=true;
	}

	function do_correction()
	{
		local corr = get_sel() - selection_index;
		foreach ( o in m_objs )
		{
			local idx = o.m_art.index_offset - corr;
			o.m_art.rawset_index_offset( idx );			
		}
	}

	function get_sel()
	{
		return vert_flow ? ( sel_x * rows + sel_y ) : ( sel_y * cols + sel_x );
	}

	function on_signal( sig )
	{
		switch ( sig )	
		{
		case "up":
			if ( vert_flow && ( sel_y > 0 ) )
			{
				sel_y--;				
				update_frame();
				move_sound();
			}	
			return true;

		case "down":
			if ( vert_flow && ( sel_y < rows - 1 ))
			{
				sel_y++;				
				update_frame();
				move_sound();
			}
			return true;

		case "left":
			if ( vert_flow && ( sel_x > 0 ))
			{
				sel_x--;
				update_frame();
				move_sound();
			}
			else if ( !vert_flow && ( sel_y > 0 ) )
			{
				sel_y--;
				update_frame();
				move_sound();
			}
			else
			{
				transition_swap_point=0.0;
				do_correction();
				fe.signal( "prev_page" );
			}
			return true;

		case "right":
			if ( vert_flow && ( sel_x < cols - 1 ) )
			{
				sel_x++;
				update_frame();
				move_sound();
			}
			else if ( !vert_flow && ( sel_y < rows - 1 ) )
			{
				sel_y++;
				update_frame();
				move_sound();
			}
			else
			{
				transition_swap_point=0.0;
				do_correction();
				fe.signal( "next_page" );
			}
			return true;

		case "exit":
		case "exit_no_menu":
			break;
						
		case "select":
		default:
			// Correct the list index if it doesn't align with
			// the game our frame is on
			//
			enabled=false; // turn conveyor off for this switch
			local frame_index = get_sel();
			fe.list.index += frame_index - selection_index;

			set_selection( frame_index );
			update_frame();
			enabled=true; // re-enable conveyor
			break;

		}

		return false;
	}

	function on_transition( ttype, var, ttime )
	{
		switch ( ttype )
		{
		case Transition.EndNavigation:			
			snap_t.visible = true;
			snap_t.video_flags = Vid.Default;
			selsound_enabled = true;
		break;

		case Transition.ToNewSelection:
			snap_t.visible = false;
			snap_t.video_flags = Vid.NoAudio;
			selsound_enabled = false;
		break;
				
                case Transition.ToNewList:
				//Update filter highlight
                for ( local i = 0; i < ui_filters.len(); i++ )
                    ui_filters[i].set_rgb(240, 240, 240);
                    ui_filters[fe.list.filter_index].set_rgb(212, 165, 33);
                break;
		}
		return base.on_transition( ttype, var, ttime );
	}
    
    
    function on_tick( stime )
    {
        // Update on-screen timer every 1 seconds
        if ( stime - last_time > 1000) {
            count--;
            ui_counter.msg = count;
            last_time = stime;
        }
        
        // If timer expired, go back to home system menu
        if ( count <= 0 ) {
            fe.signal( "displays_menu" );
        }    
    }
}

class MySlot extends ConveyorSlot
{
	m_num = 0;
	m_art = null;
	m_shadow = null;
        m_grid = null;
	m_offset = 10;

	constructor( num, grid )
	{
		m_num = num;
        m_grid = grid;
		
		local x = width - 7 * PAD;
		local y = height - 9 * PAD;

		if (my_config["art"] == "wheel") {
			m_shadow = fe.add_artwork(my_config["art"], 0, 0, x + m_offset, y + m_offset);
			m_shadow.preserve_aspect_ratio = true; 
			m_shadow.set_rgb(0,0,0);
			m_shadow.alpha = 192;		
		}
		
		m_art = fe.add_artwork(my_config["art"], 0, 0, x, y);
		m_art.preserve_aspect_ratio = true; 
		m_art.video_flags = Vid.NoAudio;
		
				
		base.constructor();
	}

	function on_progress( progress, var )
	{
        local r = m_num % rows;
        local c = m_num / rows;

        if ( abs( var ) < rows )
        {
            m_art.x = c * width + PAD + 10;
            m_art.y = fe.layout.height / 24
                + ( fe.layout.height * 11 / 12 ) * ( progress * cols - c ) + PAD + 6;
        }
        else
        {
            local prog = m_grid.transition_progress;
            if ( prog > m_grid.transition_swap_point )
            {
                if ( var > 0 ) c++;
                else c--;
            }

            if ( var > 0 ) prog *= -1;

            m_art.x = ( c + prog ) * width + PAD + 10;
            m_art.y = fe.layout.height / 24 + r * height + PAD + 6;
        }
		
		if (m_shadow) {
			m_shadow.x = m_art.x + m_offset;
			m_shadow.y = m_art.y + m_offset;
		}			
	}

	function swap( other )
	{
		m_art.swap( other.m_art );
		
		if (m_shadow) {
			m_shadow.swap( other.m_shadow );
		}				
	}

	function set_index_offset( io )
	{
		m_art.index_offset = io;
		
		if (m_shadow) {
			m_shadow.index_offset = io;
		}	
	}

	function reset_index_offset()
	{
		m_art.rawset_index_offset( m_base_io );
		
		if (m_shadow) {
			m_shadow.rawset_index_offset( m_base_io );
		}	
	}

	function set_alpha( alpha )
	{
		m_art.alpha = alpha; 
	}	
}

::gridc <- Grid();
local my_array = [];
	for (local i = 0; i < rows * cols; i++)
		my_array.push(MySlot(i, gridc));
		gridc.create_layout(my_array);
