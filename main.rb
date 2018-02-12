require 'discordrb'
require 'open-uri'
require 'pg'
$stdout.sync = false

$error = 0
$conn = PG.connect(ENV['DATABASE_URL'])
def getVals(mem)
  a = true
  puts "hi"
  $conn.exec_params('select * from users where userid=$1 and serverid=$2', [mem.distinct, mem.server.id]) do |result|
    result.each do |row|
      return row.values_at('tax', 'bal')
      a = false
    end
  end
  if a
    $conn.exec_params('insert into users (userid, serverid, tax, bal, credit) values ($1, $2, 0, 0, 0)', [mem.distinct, mem.server])
  end
end
def setStat(mem, tax, bal)
  getVals(mem)
  $conn.exec_params('update users set (tax=$1, bal=$2) where userid=$3 and serverid=$4', [tax, bal, mem.distinct, mem.server]) do |result|
    result.each do |row|
      return row.values_at('tax', 'bal')
    end
  end
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
  event.respond "pls no u garbage"
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

$bot.ready do |event|
end

class Command

  #-----------------------------
  #          COMMANDS
  #-----------------------------

  def Command.rubber(event)
    event.respond("woot")
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

  def Command.checktaxes(event, *args)
    event.message.mentions.each do |mem|
      event.respond(mem.nick)
      st = getVals(mem)
      event.respond("You owe $#{st[0].to_f * 0.50} to the IRS. You have $#{st[1].to_f * 0.01}.")
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
