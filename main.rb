require 'discordrb'
require 'open-uri'
require 'pg'

$error = 0
def link
  $conn = PG::Connection.open(ENV['DATABASE_URL'])
  yield
  $conn.close
end
def getVals(mem, type)
  a = true
  type = type.to_s
  $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
    result.each do |row|
      return row.values_at(type).first
      a = false
    end
  end
  if a
    $conn.exec_params("insert into users (userid, serverid, tax, bal, credit, taxamt, daily) values ($1, $2, 0, 500, 0, 5, 100)", [mem.distinct, mem.server.id])
    $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
      result.each do |row|
        return row.values_at(type).first
        a = false
      end
    end
  end
end
def setStat(mem, type, val)
  type = type.to_s
  getVals(mem, :tax)
  $conn.exec_params('update users set $2=$1 where userid=$3 and serverid=$4', [val, type, mem.distinct, mem.server.id])
end
prefix = '='
puts "key", ENV['KEY']
$bot = Discordrb::Bot.new token: ENV['KEY'], client_id: ENV['CLIENT']
puts $bot.invite_url
puts ARGV[0]
def command(command,event,args)
  begin
    begin
      Command.send(command,event,*args)
    rescue ArgumentError
      event.respond("Argument Error!!!1!!")
    end
  rescue NoMethodError
    event.respond("That's Not A Command!™")
  end
end

=begin
fo = File.new('daboi.png', 'w+')
fo.write open(ENV['THEMAN']).read

puts open(ENV['THENMAN']).size
=end

$bot.message(start_with: prefix) do |event|
  puts "caught command"
  cmd = event.message.content.downcase.strip
  cmd[0] = ""
  cmd = cmd.split(" ")
  top = cmd[0]
  cmd.map! {|e| e.gsub("_"," ")}
  cmd.delete_at(0)
  puts top
  command(top, event, cmd)
end

$bot.message(contains: /\W?.?c.?l.?u.?t.?\W?/i) do |event|
  event.respond "***GET THAT CANCA OUTTA HERE!!!***"
  event.message.delete
end

=begin
$bot.message() do |event|
  msga = event.message.content.split(" ")
  msga.map { |e| e.downcase }
  swra = ENV['BADWORDS'].split(', ')
  unless (msga & swra).empty?
    $bot.send_file(event.channel.id,fo)
  end
end
=end

$bot.message do |event|
  unless event.message.content[0] == "=" 
    link do
      st = getVals(event.author, :tax)
      setStat(event.author,st[0].to_i+getVals(event.author, :taxamt),nil)
    end
  end
end

class Command

  #-----------------------------
  #          COMMANDS
  #-----------------------------

  def Command.rubber(event)
    event.respond("woot")
  end
  
  def Command.version(event)
    event.respond(ENV['HEROKU_RELEASE_VERSION'])
  end

  def Command.ispaulgreat(event)
    event.respond("yea " + event.author.mention)
  end

  def Command.setplaying(event, text)
    if event.author.distinct=="PenguinOwl#3931"
      $bot.game= text
    else
      event.respond "but ur not penguin"
    end
  end

  def Command.taxes(event, *args)
    link do
      if event.message.mentions.size == 0
        mem = event.author
        event.respond("You owe $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01} to the IRS. You have $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.")
      end
      event.message.mentions.each do |mem|
        mem = mem.on(event.channel.server)
        event.respond(mem.mention + " owes $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01} to the IRS. They have $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.")
      end
    end
  end
  
  def Command.info(event, *args)
    link do
      conc = ""
      if event.message.mentions.size == 0
        mem = event.author
        conc = "**" + mem.nick + "**'s Stats```Tax: $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01}\nBalence: $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}\nDaily Reward: $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01}\nTax Rate: $#{sprintf "%.2f", getVals(mem, :taxamt).to_f * 0.01} per message\nInvestments: #{getVals(mem, :invest).to_s}```"
      end
      event.message.mentions.each do |mem|
        mem = mem.on(event.channel.server)
        conc = "**" + mem.nick + "**'s Stats```Tax: $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01}\nBalence: $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}\nDaily Reward: $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01}\nTax Rate: $#{sprintf "%.2f", getVals(mem, :taxamt).to_f * 0.01} per message\nInvestments: #{getVals(mem, :invest).to_s}```"
      end
      event.respond conc
    end
  end
  
  def Command.daily(event)
    mem = event.author
    link do
      unless getVals(mem, :day) == Today.to_s
        setStat(mem, :bal, getVals(mem, :daily) + getVals(mem, :bal))
        setStat(mem, :day, Today.to_s)
        event.respond "Collected $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01} from the bank."
      end
    end
  end
  
  def Command.>(event, *args)
    if event.author.distinct=="PenguinOwl#3931"
      puts args.join " "
      event.respond eval args.join(" ")
    else
      event.respond "boi stop tryn to hack me"
    end
  end

  #-----------------------------
  #       END OF COMMANDS
  #-----------------------------

end
  
$bot.run 
