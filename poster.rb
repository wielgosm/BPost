module BPost
  require 'net/http'
  require 'nokogiri'
  require 'open-uri'
  require 'json'
  require 'simple_xlsx'

  class BPostManager
    attr_reader :thread_count
    def initialize(send_data, get_procs, options)
      @send_data = send_data
      @get_procs = get_procs
      @url       = options['url']
      @action    = options['action']
      @instances = options['instances']
      @oformat   = options['oformat']
      @iformat   = options['iformat']
      @debug     = options['debug']
      @try       = options['try']
      @name      = options['name']
      @cleanup   = options['cleanup']
      @threads   = []
      @data      = Hash.new

      validate_variables
      start_threads
      finish_threads
      cleanup_data if @cleanup
      create_spreadsheet if @oformat == :excel
      @data
    end
    def update_thread
      i = BThread.current.i
      @threads[i] = BThread.new(i) { perform_action }
      BThread.current.kill
    end

    private
    def cleanup_data
      @data.each do |key,value|
        @cleanup.call value
      end
    end
    def create_spreadsheet
      puts "Generating spreadsheet" if @debug
      name = "output.xlsx"
      name = @name if @name
      SimpleXlsx::Serializer.new("#{name}.xlsx") do |doc|
        doc.add_sheet("sheet") do |sheet|
          @data.each do |key,value|
            sheet.add_row value
          end
        end
      end
    end
    def validate_variables
      raise ArgumentError, "Data sent must be an array of hashes" unless @send_data.class == Array
      raise ArgumentError, "Data sent must be an array of hashes" unless @send_data[0].class == Hash
      raise ArgumentError, "Data sent must be at lest of size 1" if @send_data.size == 0
      
      raise ArgumentError, "Process variable must be an array of procs" unless @get_procs.class == Array
      raise ArgumentError, "Process variable must be an array of procs" unless @get_procs[0].class == Proc
      raise ArgumentError, "Process variable must be at lest of size 1" if @get_procs.size == 0
      
      @url = URI.parse(@url) unless @url.class == URI::HTTP or @action == :get
    end
    def create_get_string(hash)
      temp = @url.clone
      temp.concat('?')
      hash.each do |key,value|
        temp.concat(key.to_s + '=' + value.to_s + '&')
      end
      temp_rem = temp.slice(0...(temp.length-1))
      temp_rem = URI.parse(temp_rem)
      temp_rem
    end
    def start_threads
      (0...@instances).each do |i|
        @threads.push(BThread.new(i) { perform_action })
        sleep 0.1
      end
      Thread.new do
        while true
          old_send_size = @send_data.size
          old_get_size  = @data.size
          sleep 10
          new_send_size = @send_data.size
          new_get_size  = @data.size
          avg_send = (old_send_size.to_f-new_send_size.to_f)/10.0
          avg_get  = (new_get_size.to_f-old_get_size.to_f)/10.0
          puts "Sending #{avg_send} entries per second."
          puts "Getting #{avg_get} entries per second."
          counter = 0
          @threads.each do |thread|
            if thread.alive? then
              counter +=1
            end
          end
          puts "There are #{counter} threads alive."
        end
      end
    end
    def finish_threads
      i = 0
      counter = 0
      while i < @threads.size do
        if @threads[i].alive? then
          sleep 10
          i = -1
        end
        i += 1
      end
      @threads.each do |thread|
        thread.join
      end
    end
    def perform_action
      send = @send_data.pop
      if send then
        begin
          if @action == :post then
            if @iformat == :html then
              doc  = Nokogiri::HTML(Net::HTTP.post_form(@url, send).body)
            elsif @iformat == :json then
              doc = Net::HTTP.post_form(@url,send)
              doc.strip!
              if doc[0] == '(' then
                doc = doc[1,doc.length-2]
              end
              doc = JSON.parse doc
            end
          elsif @action == :get then
            url = create_get_string(send)
            puts url.to_s if @debug
            if @iformat == :html then
              doc = Nokogiri::HTML(Net::HTTP.get(url))
            elsif @iformat == :json then
              doc = Net::HTTP.get(url)
              doc.strip!
              if doc[0] == '(' then
                doc = doc[1,doc.length-2]
              end
              doc = JSON.parse doc
            end
          end
          @get_procs.each_with_index do |pr,i|
            res = pr.call(doc)
            unless @data.has_key? res[0] or res == nil or res == [] then
              @data.store(res[0],res)
            end
          end
          if @try == true then
            update_thread unless @data.size > 5
          else
            update_thread
          end
        rescue Exception => e
          puts "Error"
          puts e.message  
          puts e.backtrace.inspect
          update_thread
        end
      else
        BThread.current.kill
      end
    end
  end
  class BThread < Thread
    attr_reader :i
    def initialize(i,*arg,&block)
      @i = i
      super(*arg,&block)
    end
  end
end
