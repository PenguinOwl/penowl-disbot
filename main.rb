require 'discordrb'
#tba
prefix = '['
bot = Discordrb::Bot.new token: File.open("creds.txt","r+").read.strip, client_id: 355508728344084511
puts bot.invite_url
def command(command,event,args)
  begin
    begin
      send(command,event,*args)
    rescue ArgumentError
      event.respond("Argument Error!!!1!!")
    end
  rescue NoMethodError
    event.respond("That's Not A Command!™")
  end
end

bot.message(start_with: prefix) do |event|
  puts "caught command"
  cmd = event.message.content.downcase.strip
  cmd[0] = ""
  cmd = cmd.split(" ")
  top = cmd[0]
  cmd.delete_at(0)
  puts top
  command(top, event, cmd)
end

Thread.new {while gets=="stop" do bot.stop end}

  #-----------------------------
  #          COMMANDS
  #-----------------------------

  def rubber(event)
    event.respond("woot")
  end

  def ispaulgreat(event)
    event.respond("yea " + event.author.mention)
  end


  #-----------------------------
  #       END OF COMMANDS
  #-----------------------------

  bot.run
