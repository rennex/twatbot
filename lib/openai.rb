require 'cgi'
require 'unirest'
require 'time'
require 'thread'
require 'csv'
require 'date'
require 'timezone_finder'
require 'ruby/openai'
require 'pastebinrb'
require 'unirest'
require 'word_wrap'
require 'open-uri'
require 'securerandom'


module Plugins
  class OpenAI
    include Cinch::Plugin

    set :react_on, :message
    
    match /^!(?:help|commands)/, use_prefix: false, method: :help
    match /^!gpt3bot\s+(\S.*$)/, use_prefix: false, method: :gpt3bot
    match /^!gpt3pic\s+(\S.*$)/, use_prefix: false, method: :gpt3pic
    
    def initialize(*args)
      super
      @config = bot.botconfig

      @client = ::OpenAI::Client.new(access_token: @config[:OPENAI_SECRET_KEY])
      @pastebin = Pastebinrb::Pastebin.new @config[:OPENAI_PASTEBIN_DEVKEY]

      @apicalls_minute = []
      @apicalls_day = []
      @apicalls_mutex = Mutex.new

      @piccalls_minute = []
      @piccalls_day = []
      @piccalls_mutex = Mutex.new

    end

    def help(m)
      m.user.notice  "\x02\x0304OPENAI:\n\x0f" +
      "\x02  !gpt3bot <input>\x0f - Talk to OpenAI gpt3bot\n" +
      "\x02  !gpt3pic\x0f - Talk to OpenAI gpt3bot DALL-E"
    end
    
    def check_api_rate_limit(x=1)
      now = Time.now.to_i
      minute_ago = now - 60
      day_ago = now - (60*60*24)
      
      @apicalls_minute = @apicalls_minute.take_while { |x| x >= minute_ago }
      @apicalls_day = @apicalls_day.take_while { |x| x >= day_ago }
      
      if (@apicalls_minute.size + x) <= @config[:OPENAI_API_RATE_LIMIT_MINUTE] && (@apicalls_day.size + x) <= @config[:OPENAI_API_RATE_LIMIT_DAY]
        return true
      else
        return false
      end    
    end

    def check_pic_rate_limit(x=1)
      now = Time.now.to_i
      minute_ago = now - 60
      day_ago = now - (60*60*24)
      
      @piccalls_minute = @piccalls_minute.take_while { |x| x >= minute_ago }
      @piccalls_day = @piccalls_day.take_while { |x| x >= day_ago }
      
      if (@piccalls_minute.size + x) <= @config[:OPENAI_PIC_RATE_LIMIT_MINUTE] && (@piccalls_day.size + x) <= @config[:OPENAI_PIC_RATE_LIMIT_DAY]
        return true
      else
        return false
      end    
    end

    
    def gpt3bot(m, question)
      botlog "", m
      question.strip!

      if m.bot.botconfig[:OPENAI_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:OPENAI_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      
        
      @apicalls_mutex.synchronize do
        if !check_api_rate_limit(1)
          errormsg = "ERROR: OpenAI API rate limiting in effect, please wait 1 minute and try your request again. (API calls in last minute = #{@apicalls_minute.size}, last day = #{@apicalls_day.size}) [Error: API_LIMIT_A]"
          botlog errormsg, m
          #m.user.notice errormsg
          m.reply errormsg
          return
        end
          
        loop do      
          if !check_api_rate_limit(1)
            errormsg = "ERROR: OpenAI API rate limiting in effect, please wait 1 minute and try your request again. (API calls in last minute = #{@apicalls_minute.size}, last day = #{@apicalls_day.size}) [Error: API_LIMIT_B]"
            botlog errormsg, m
            m.reply errormsg
            return
          end

          response = @client.completions(
            parameters: {
            model: "text-davinci-003",
            prompt: question,
            max_tokens: 256
          })

          @apicalls_day.unshift(Time.now.to_i)
          @apicalls_minute.unshift(Time.now.to_i)   

          r_raw = response.dig("choices", 0, "text").to_s
          r = r_raw.strip.gsub(/[\n]/, ", ").gsub(/[\t]/, " ")

          p = Unirest::post("https://api.paste.ee/v1/pastes",  headers:{ "X-Auth-Token" => m.bot.botconfig[:OPENAI_PASTEBINEE_DEVKEY], "content-type" => 'application/json' }, parameters: {"description" => question[0..63],"sections" => [{"name" => question[0..63],"syntax" => "text","contents" => WordWrap.ww(question + "\n\n" + r_raw, 120)}]}.to_json) 
          if p.body.dig("link").nil?
            puts p.inspect
            p = ""
          else
            p = " :: " + "\x03" + "07" + p.body.dig("link") + "\x0f" 
          end


          if r && r.length >=0
            r = m.user.to_s + ": " + "\x02" + "[gpt3bot:] " + "\x0f"+ r

            if r.length > 410
              r = r[0..409]
            end

            m.reply r + p
          end

          break       

        end

      end
  
    end


    def gpt3pic(m, question)
      botlog "", m
      question.strip!

      if m.bot.botconfig[:OPENAI_EXCLUDE_CHANS].map(&:downcase).include?(m.channel.to_s.downcase) || m.bot.botconfig[:OPENAI_EXCLUDE_USERS].map(&:downcase).include?(m.user.to_s.downcase)
        return
      end

      #if m.user.downcase != 'moesizlak'
      ##  m.reply "Permission denied."
      #  return
      #end

      
        
      @piccalls_mutex.synchronize do
        if !check_pic_rate_limit(1)
          errormsg = "ERROR: OpenAI DALL-E image generation rate limiting in effect, please wait 24 hours and try your request again. (API calls in last minute = #{@piccalls_minute.size}, last day = #{@piccalls_day.size}) [Error: PIC_LIMIT_A]"
          botlog errormsg, m
          #m.user.notice errormsg
          m.reply errormsg
          return
        end
          
        loop do      
          if !check_pic_rate_limit(1)
            errormsg = "ERROR: OpenAI DALL-E image generation rate limiting in effect, please wait 24 hours and try your request again. (API calls in last minute = #{@piccalls_minute.size}, last day = #{@piccalls_day.size}) [Error: PIC_LIMIT_B]"
            botlog errormsg, m
            m.reply errormsg
            return
          end

          response = @client.images.generate(parameters: { prompt: question })

          @piccalls_day.unshift(Time.now.to_i)
          @piccalls_minute.unshift(Time.now.to_i)   

          r = response.dig("data", 0, "url")




          if r && r.length >=0
            imagefile = Time.now.utc.strftime("%Y%m%d%H%M%S") + "-" + SecureRandom.uuid + '.png'

            open('/var/www/newzbin.bitlanticcity.com/public/images/urldb/' + imagefile, 'wb') do |file|
              file << URI.open(r).read
            end



            r = m.user.to_s + ": " + "\x02" + "[gpt3pic:] " + "\x0f"+ 'https://newzbin.bitlanticcity.com/images/urldb/' + imagefile

             entries = m.bot.botconfig[:DB][:TitleBot]
            entries.insert(:Date => Sequel.function(:now), :Nick => m.user.to_s, :URL => 'https://newzbin.bitlanticcity.com/images/urldb/' + imagefile, :Title => 'gpt3pic: ' + question, :ImageFile => imagefile)

            m.reply r
          else
            puts response.inspect
            r = response.parsed_response.dig("error", "message")
            if r && r.length > 0
              m.reply m.user.to_s + ": " + "\x02" + "[gpt3pic:] " + "\x0f"+ r
            end
          end

          break       

        end

      end


  
    end


  end
end
    