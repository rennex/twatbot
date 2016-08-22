require 'unirest'
require 'time'
require 'ruby-duration'


module URLHandlers
  class Youtube
    def self.parse(url)      
      if(url =~ /.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|watch\?(?:(?!v=)[^&]+&)+v=)([^#\&\?\s]*).*/i)
        id = $1
        search = Unirest::get("https://www.googleapis.com/youtube/v3/videos?id=" + id + "&key=" + MyApp::Config::YOUTUBE_GOOGLE_SERVER_KEY + "&part=snippet,contentDetails,statistics,status")
        
        if search.body && search.body.key?("items") && search.body["items"].size > 0
          if search.body["items"][0].key?("snippet") 
            if search.body["items"][0]["snippet"].key?("publishedAt")
              publishedAt = search.body["items"][0]["snippet"]["publishedAt"]
              if publishedAt.size > 0
                publishedAt = DateTime.iso8601(publishedAt).strftime("%Y-%m-%d")
              end
            end
            
            if search.body["items"][0]["snippet"].key?("title")
              title = search.body["items"][0]["snippet"]["title"]
              end
            
            if search.body["items"][0]["snippet"].key?("description")
              description = search.body["items"][0]["snippet"]["description"]
            end      
          end
          
          if search.body["items"][0].key?("contentDetails") 
            if search.body["items"][0]["contentDetails"].key?("duration")
              duration = search.body["items"][0]["contentDetails"]["duration"]
              if duration.size > 0
                duration = Duration.load(duration).format("%tm:%S")
              end
            end  
          end
          
          if search.body["items"][0].key?("statistics") 
            if search.body["items"][0]["statistics"].key?("viewCount")
              viewCount = search.body["items"][0]["statistics"]["viewCount"]
            end  
            
            if search.body["items"][0]["statistics"].key?("likeCount")
              likeCount = search.body["items"][0]["statistics"]["likeCount"]
            end  
            
            if search.body["items"][0]["statistics"].key?("dislikeCount")
              dislikeCount = search.body["items"][0]["statistics"]["dislikeCount"]
            end  
          end
          
          if(viewCount.nil?)
            viewCount = 0
          end
          
          if(likeCount.nil?)
            likeCount = 0
          end
          
          if(dislikeCount.nil?)
            dislikeCount = 0
          end
          
          color_yt = "03"     
          color_name = "04"
          color_rating = "07"
          color_url = "03"
          
          myreply = "\x03".b + color_yt + "[YouTube] " + "\x0f".b + 
          "\x03".b + color_name + (title.nil? ? "UNKOWN_TITLE" : title) + "\x0f".b +
          "\x03".b + color_rating +
          (duration.nil? ? ""    : (" (" + duration    + ")")) +    
          (publishedAt.nil? ? "" : (" [" + publishedAt + "]")) +
          " ["         + viewCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + 
          " views] [+" + likeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + 
          "/-"         + dislikeCount.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse + "]" +
          "\x0f".b
          
          return myreply
        end      
      end
      return nil
    end    
  end
end