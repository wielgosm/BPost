## Notes and Features ##
BPost is a Ruby module that allows you to easily perform batch POST and GET requests to web forms.  
It is still under development. Some of it's current features are:  
* POST and GET form submission  
* JSON and HTML document parsing  
* Ability to perform multiple simultaneous requests  
* Try functionality to test the submission  
* Data cleanup  
* Debug functionality  
* Output as an XLSX spreadsheet  
  
## Requirements ##

There are a few gems that BPost requires. They are:  
* Net/http  
* Nokogiri  
* Open-Uri  
* Json  
* Simple_Xlsx  

BPost has been written under and tested with Ruby 1.9.2.  

## Installation ##
Install the required gems, that's all.  
  
    gem install nokogiri  
    gem install json  
    gem install simple_xlsx_writer  

## Examples ##
Here are some typical cases. Notice these examples WILL NOT WORK.  
They are all hypothetical.   

### The output of a document is HTML ###
    require "poster.rb"  
    # First thing first - we need som data to send  
    # In this example, we send a list of zip codes from a file  
    # along with some other information required by the form  
    send_data = []  
    File.open("data/zip_codes").each_line do |line|  
      send_data << {'searchType' => 'PostalCode',  
                    'Count' => '25',  
                    'ZipCode' => line.slice(0..4)}  
    end  
      
    # Now we need an array of get procs. If there are 5 items you would like to  
    # get from a website - create 5 of these. The doc arguement could be an Nokogiri  
    # document on a JSON ruby object. You choose the document type later on.  
    get_procs = []  
    get_procs << Proc.new do |doc|  
      # this info array is actually the thing that will get saved later on - this is our data!  
      # here we choose the html data from the document  
      info_ar = []  
      # The first item in our array is a key - well, a primary key. we need to make sure it's unique.  
      # If it's not unique, or data may get overriden by another entry with the same key.  
      # A good example of this is a list of dealerships. If we are trying to obtain a list like this  
      # we need to make sure that two dealers with the same name do not get overridden. In this example  
      # we take some data from the document and essentially combine it into a single item.  
      info_ar << doc.css(".info h3")[0].inner_text.to_s + doc.css(".info")[0].css("li")[1].inner_text.to_s rescue nil  
      info_ar << doc.css(".info")[0].css("li")[1].inner_text rescue info_ar << ""  
      info_ar << item_str  
      # return the value back - it's ready to be saved unless we decide to create a cleanup proc  
      info_ar  
    end  
    # Here we do the same thing - but grab the second item on the page  
    get_procs << Proc.new do |doc|  
      info_ar << doc.css(".info h3")[1].inner_text.to_s + doc.css(".info")[1].css("li")[1].inner_text.to_s rescue nil  
      info_ar << doc.css(".info")[1].css("li")[1].inner_text rescue info_ar << ""  
      info_ar << item_str  
      # return the value back - it's ready to be saved unless we decide to create a cleanup proc  
      info_ar  
    end  
    # And so on... We can grab as many items from a page as we want.  
  
    # The fun almost begins... But first we need to pass some extra parameters, a hash of parameters.  
    options = { 'url'       => 'http://www.somewebsite.com/form.php', # the url we will be sending the data to  
                'name'      => 'somename',                            # the name of the list - will be used in the output filename, ex: somename.xlsx  
                'action'    => :get,                                  # the action to take - either get or post  
                'instances' => 5,                                     # number of simultaneous requests to perform... please don't make this too high  
                'debug'     => true,                                  # some debug information  
                'oformat'   => :excel,                                # the output format, currently only :excel is supported, which will generate .xlsx file  
                'iformat'   => :html,                                 # the format of the document  
                'try'       => false }                                # if we set this to true, we will only send 10 requests and the program will quit  

    # Let the fun begin!  
    BPost::BPostManager.new(send_data,get_procs,options)  
