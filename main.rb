#! /usr/bin/ruby

require "rubygems"
require "compass"
require "sass"
require "sinatra"
require "sinatra/base" 
require "sinatra/assetpack"
require "sinatra/content_for"
require "sinatra/partial"

configure :production do
	require "newrelic_rpm"
end

require_relative "server/model/database"

configure :development do
	require "server/model/seeds"
end

class HikeApp < Sinatra::Base

	set :root, File.dirname(__FILE__)

	# sinatra-partial setup
	register Sinatra::Partial
	set :partial_template_engine, :erb

	# Sass setup 
	set :sass, Compass.sass_engine_options
	set :sass, { :load_paths => sass[:load_paths] + [ "#{HikeApp.root}/app/css" ] }
	set :scss, sass

	# content_for setup
	helpers Sinatra::ContentFor

	# AssetPack setup
	register Sinatra::AssetPack

	Compass.configuration do |config|
		config.project_path = File.dirname(__FILE__)
		config.sass_dir = "#{HikeApp.root}/app/css" 
	end

	assets {
		prebuild true

		js :app, "/js/app.js", [
			"/js/*.js",
			"/js/lib/*.js"
		]

		css :app, "/css/app.css", [
			"/css/*.css",
			"/css/lib/*.css"
		]

		js_compression  :jsmin
   		css_compression :sass
	}

	helpers do

		def root
			File.dirname(__FILE__)
		end
		
		def pictures
			[Picture.new({:id => "scotchmans-peak-trees"}),
			 Picture.new({:id => "scotchmans-peak-mountain-goat"}),
			 Picture.new({:id => "scotchmans-peak-wildflower"}),
			 Picture.new({:id => "scotchmans-peak-meadow"}),
			 Picture.new({:id => "scotchmans-peak-pend-orielle"}),
			 Picture.new({:id => "scotchmans-peak-zak"}),
			 Picture.new({:id => "scotchmans-peak-mountain-goat-cliff"}),
			 Picture.new({:id => "scotchmans-peak-hikers"}),
			 Picture.new({:id => "scotchmans-peak-dead-tree"})]
		end

		def map
			Map.new({:latitude => 48.177534, :longitude => -116.089783, :href => "https://maps.google.com/maps?q=Scotchman's+Peak,+ID+83811&hl=en&sll=48.177534,-116.089783&sspn=0.489924,0.495071&t=h&hq=Scotchman's+Peak,&hnear=Clark+Fork,+Bonner,+Idaho&ie=UTF8&ll=48.166314,-116.06987&spn=0.245015,0.247536&z=12&vpsrc=6&cid=1851277074294752467&iwloc=A"})
		end

		def all_entries
			[Entry.new({
				:id => "scotchmans-peak", 
				:name => "Scotchman's Peak",
				:location => "North Idaho, USA", 
				:distance => 10,
				:elevation_gain => 1000,
				:pictures => pictures, 
				:map => map}),
			Entry.new({
				:id => "king-arthurs-seat", 
				:name => "King Arthur's Seat", 
				:location => "Edinburgh, Scotland", 
				:distance => 3,
				:elevation_gain => 1000,
				:pictures => pictures, 
				:map => map}),
			Entry.new({
				:id => "north-kaibab-trail", 
				:name => "North Kaibab Trail", 
				:location => "Grand Canyon, USA", 
				:distance => 15,
				:elevation_gain => 1000,
				:pictures => pictures, 
				:map => map}),
			Entry.new({
				:id => "lake-22", 
				:name => "Lake 22", 
				:location => "Washington, USA", 
				:distance => 18,
				:elevation_gain => 2500,
				:pictures => pictures, 
				:map => map}),
			Entry.new({
				:id => "pikes-peak", 
				:name => "Pike's Peak", 
				:location => "Colorado, USA", 
				:distance => 30,
				:elevation_gain => 3000,
				:pictures => pictures, 
				:map => map}),
			Entry.new({
				:id => "snoqualmie-middle-fork", 
				:name => "Snoqualmie Middle Fork", 
				:location => "Washington, USA", 
				:distance => 11,
				:elevation_gain => 4352,
				:pictures => pictures, 
				:map => map}),
			Entry.new({:id => "mt-kilamanjaro", 
				:location => "North Idaho, USA", 
				:name => "Mt. Kilamanjaro", 
				:location => "Tanzania", 
				:distance => 50,
				:elevation_gain => 1000,
				:pictures => pictures, 
				:map => map})]
		end

		def featured_entry 
			all_entries[0];
		end

		def popular_list
			all_entries[1..-1]
		end

		def find_entry id
			all_entries.select { |entry|
				entry[:string_id] == id
			}[0]
		end

		def distance_string distance
			# Distance is in km (that's right).
			miles = (distance * 0.621371).round(1)
			"#{miles} mi."
		end

		def elevation_string elevation
			feet = (elevation * 3.28084).round(0)
			sign = "+" unless (feet < 0)
			"#{sign}#{feet} ft."
		end

		# Assumes the svg file has already passed through the process_svg script
		def render_svg(path, attributes=nil)

			render_str = ""

			if supports_svg?
				render_str = File.open("#{root}/app/#{path}", "rb").read
			else
				# Remove the extension
				arr = path.split(".")
				arr.pop

				# Assumes we have a backup png
				path = arr.join(".") + ".png"

				render_str = img path;
			end

			# Add any attributes provided
			if attributes
				attr_str = ""
				attributes.each { |key, value|
					attr_str += "#{key}=\"#{value}\" "
				}
				render_str.insert(4, " #{attr_str}");
			end

			render_str
		end

		def supports_svg?
			# Naughty, naughty, sniffing the user agent. I'm not happy with any of the polyfills, 
			# and really would like to use svgs for icons, so it must be done.
			ua = request.user_agent
			not (ua.include? "Android 2" or 
				 ua.include? "MSIE 6" 	 or 
				 ua.include? "MSIE 7" 	 or 
				 ua.include? "MSIE 8")
		end

		def is_iPhone?
			request.user_agent.include? "iPhone"
		end

	end

	before do
		if settings.environment == :development
			@entry_img_dir = "/hike-images"
		else
			@entry_img_dir = "http://assets.hike.io/hike-images"
		end

		@img_dir = "/images"
	end

	get "/" do
		@title = "hike.io - Beautiful Hikes"
		@featured_entry = Entry.first
		@entries = Entry.where(:id => @featured_entry.id).invert
		erb :index
	end

	get "/:entry_id", :provides => 'html' do
		@entry = Entry[:string_id => params[:entry_id]]
		pass unless @entry
		@title = @entry.name
		erb :entry
	end

	 # start the server if ruby file executed directly
	run! if app_file == $0
end