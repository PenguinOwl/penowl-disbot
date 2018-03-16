require 'discordrb'
require 'open-uri'
require 'pg'
require 'date'

$conn = 0
$error = 0
$pres = <<here
  ___ ___ ___ ___ _____ ___ ___ ___ 
 | _ \ _ \ __/ __|_   _|_ _/ __| __|
 |  _/   / _|\__ \ | |  | | (_ | _| 
 |_| |_|_\___|___/ |_| |___\___|___|
here
class String
  def pad(align="center")
    fin = ""
    lg = 0
    d = self.dup.split("\n")
    d.each do |str|
      length = str.center(str.length+2).length
      lg = length if lg < length
    end
    fin << "+" + ("-" * lg) + "+\n"
    d.each do |str|
      if str == "$$"
        fin << "+" + ("-" * lg) + "+\n"
      else
        dec = align
        if str[0..1] == "~<"
          dec = "ljust"
          str[0..1] == ""
        elsif str[0..1] == "~>"
          dec = "rjust"
          str[0..1] == ""
        elsif str[0..1] == "~^"
          dec = "center"
          str[0..1] = ""
        end
        fin << "|" + str.send(dec, lg) + "|\n"
      end
    end
    fin << "+" + ("-" * lg) + "+\n"
    return fin
  end
  def mon
    d = self.dup
    d = d.to_f * 0.01
    t = -1
    pr = ""
    t, pr = case d
      when (10**6)..((10**9)-1); [1, "M"]
      when (10**9)..((10**12)-1); [2, "B"]
      when (10**12)..((10**15)-1); [3, "T"]
      when (10**15)..((10**18)-1); [4, "Qu"]
      when (10**18)..((10**21)-1); [5, "Qi"]
      when d < (10^21); [6, "S"]
    else
      [-1, ""]
    end
    t = 3 * t
    t = t + 3
    t = 10**(t)
    d = d / t
    r = sprintf "%.2f", d
    r = r.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    r << pr
    return r
  end
end
def pres(mem)
  log(mget(mem, :bal)).to_i - 5
end
def todays
  Time.now.strftime("%Y=%m=%H")
end
def taxdays(mydate)
    mydate.month != mydate.next_day.next_day.next_day.next_day.next_day.month 
end
def link
  $conn = PG::Connection.open(ENV['DATABASE_URL'])
  yield
  unless $conn.finished? then 
    $conn.close 
  end
end
def pGet(mem, type)
  a = true
  type = type.to_s
  $conn.exec_params("select * from prestige where discrim=$1", [mem.distinct]) do |result|
    result.each do |row|
      return row.values_at(type).first
      a = false
    end
  end
  if a
    $conn.exec_params("insert into prestige (discrim, lvl, steal, bonus, auto) values ($1, 0, 0, 0, 0)", [mem.distinct])
    $conn.exec_params("select * from users where discrim=$1", [mem.distinct, mem.server.id]) do |result|
      result.each do |row|
        return row.values_at(type).first
        a = false
      end
    end
  end
end
def pSet(mem, type, val)
  type = type.to_s
  mget(mem, :lvl)
  $conn.exec_params("update users set #{type}=$1 where discrim=$2", [val, mem.distinct, mem.server.id])
end
def mget(mem, type)
  a = true
  type = type.to_s
  $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
    result.each do |row|
      return row.values_at(type).first
      a = false
    end
  end
  if a
    $conn.exec_params("insert into users (userid, serverid, tax, bal, credit, taxamt, daily, invest, invcost, lbcount, state, pres) values ($1, $2, 0, 700, 0, 5, 150, 0, 500, 0, 0, 0)", [mem.distinct, mem.server.id])
    $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
      result.each do |row|
        return row.values_at(type).first
        a = false
      end
    end
  end
end
def mset(mem, type, val)
  type = type.to_s
  mget(mem, :tax)
  $conn.exec_params("update users set #{type}=$1 where userid=$2 and serverid=$3", [val, mem.distinct, mem.server.id])
end
$prefix= '='
puts "key", ENV['KEY']
$bot = Discordrb::Bot.new token: ENV['KEY'], client_id: ENV['CLIENT']
puts $bot.invite_url
puts ARGV[0]
def command(command,event,args)
  if ENV['DEBUG'] == 'true'
    unless mget(event.author, :state) == "1" and not command == "unfreeze"
      Command.send(command,event,*args)
    else
      event.respond "**Your account is frozen! Unfreeze it with** `#{$prefix}unfreeze`"
    end
  else
    begin
      begin
        unless mget(event.author, :state) == "1" and not command == "unfreeze"
          Command.send(command,event,*args)
        else
          event.respond "**Your account is frozen! Unfreeze it with** `#{$prefix}unfreeze`"
        end
      rescue ArgumentError
        mem = event.author
        if mget(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)  && mget(mem, :state) == "0"
          mset(event.author, :tax, mget(event.author, :tax).to_i+mget(event.author, :taxamt).to_i)
        end
        event.respond("Argument error!")
      end
    rescue NoMethodError
      mem = event.author
      if mget(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        mset(event.author, :tax, mget(event.author, :tax).to_i+mget(event.author, :taxamt).to_i)
      end
      event.respond("That's not a command!")
    end
  end
end

$bot.message() do |event|
  link do
    if event.message.content.strip[0] == $prefix
      puts "caught command"
      cmd = event.message.content.strip
      unless cmd[1] == ">"
        cmd.downcase!
      end
      cmd[0] = ""
      cmd = cmd.split(" ")
      top = cmd[0]
      cmd.map! {|e| e.gsub("_"," ")}
      cmd.delete_at(0)
      puts top
      command(top, event, cmd)
      mem = event.author
    end
    puts event.author
    tax(event.author, event)
  end
end

def tax(dfs, event)
  begin
    mem = dfs.on(event.channel.server)
    if mget(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
      mset(mem, :tax, mget(event.author, :tax).to_i+mget(mem, :taxamt).to_i)
    end
  rescue NoMethodError
  end
end

def af(em, cmd, ds)
  em.add_field(name: $prefix+cmd, value: ds)
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
    mem = event.author
    if event.message.mentions.size == 0
      if mget(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        event.respond("You owe $#{mget(mem, :tax).mon} to the IRS. You have $#{mget(mem, :bal).mon}.")
      else
        event.respond("You have paid your taxes.")
      end
    end
    event.message.mentions.each do |mem|
      if mget(mem.on(event.channel.server), :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        mem = mem.on(event.channel.server)
        event.respond(mem.mention + " owes $#{mget(mem, :tax).mon} to the IRS. They have $#{mget(mem, :bal).mon}.")
      else
        event.respond(mem.mention + " has paid their taxes.")
      end
    end
  end
  
  def Command.freeze(event, arg="elolo")
    if arg == "confirm"
      mem = event.author
      mset(mem, :state, 1)
      event.respond("**Your account has been frozen.**")
    else
      event.respond("**" + event.author.mention + ", are you sure that you want to freeze your account? This action will reset your balance. If you are sure you want to proceed, do** `#{$prefix}freeze confirm`")
    end
  end
  
  def Command.prestige(event, arg="elolo")
    mem = event.author
    if pres mem > 0
      if arg == "confirm"
        mem = event.author
        pset(mem, :lvl, pget(mem, :lvl).to_i + 1)
        $conn.exec_params("delete from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id])
        event.respond("@here " + mem.mention + " has decided to ```" + ($pres + "~^" + mem.distinct).pad + "```")
      else
        event.respond("**" + event.author.mention + ", are you sure that you want to prestige? This action will reset your entire account except your prestige level and upgrades. If you are sure you want to proceed, do** `#{$prefix}prestige confirm`")
      end
    else
      event.respond "You need at least 1M to prestige!"
    end
  end
  
  def Command.unfreeze(event)
    mem = event.author
    mset(mem, :bal, 0)
    mset(mem, :state, 0)
    event.respond("**Your account has been unfrozen and your balance has been reset.**")
  end
  
  def Command.money(event, *args)
    mem = event.author
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      event.respond("**You have $#{mget(mem, :bal).mon}.**")
    end
    event.message.mentions.each do |mem|
      mem = mem.on(event.channel.server)
      event.respond("**" + mem.mention + " has $#{mget(mem, :bal).mon}.**")
    end
  end
  
  def Command.top(event, type="daily")
    if ["bal","daily","invest","lbcount"].include? type
      out = "~^Leaderboard of #{event.channel.server.name}"
      out << "\n~^By " + case type
        when "bal"; "Balance"
        when "daily"; "Hourly Rewards"
        when "invest"; "Investments"
        when "lbcount"; "Lobbys"
      end + "\n$$"
      serverid = event.channel.server.id
      $conn.exec_params("select userid, #{type} from users where serverid=$1 and state!=1 order by #{type} desc limit 10", [event.channel.server.id]) do |result|
        a = 1
        result.each do |row|
          r = row
          out << "\n #{a.to_s}. #{r["userid"]} - #{ if ["invest","lbcount"].include? type then "$#{r[type].mon.to_s}" else "#{r[type].to_s}" end}"
          a = a + 1
        end
      end
      event.respond("```" + out.pad("ljust") + "```")
    else
      event.respond "Not a vaild ladder!"
    end
  end
  
  def Command.id(event, *args)
    mem = event.author
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      event.respond("**You are id $#{mget(mem, :id)}.**")
    end
    event.message.mentions.each do |mem|
      mem = mem.on(event.channel.server)
      event.respond("**" + mem.mention + " is id $#{mget(mem, :id)}.**")
    end
  end
  
  def Command.richest(event)
    money(event, "bal")
  end
    
  def Command.balance(event, *args)
    money(event, *args)
  end
  
  def Command.stats(event, *args)
    info(event, *args, "noborder")
  end
  
  def Command.bal(event, *args)
    money(event, *args)
  end
  
  def Command.collect(event, *args)
    reward(event, *args)
  end
  
  def Command.info(event, *args)
    mem = event.author
    conc = ""
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      s = ""
      if mget(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
         s = "$" + mget(mem, :tax).mon
      else
         s = "Paid"
      end
      mem = event.author
      n = ""
      if mem.nick
        n = mem.nick
      else
        n = mem.username
      end
      conc = n + "'s Stats\n$$\nTax: #{s}\nBalance: $#{mget(mem, :bal).mon}\nHourly Reward: $#{mget(mem, :daily).mon}\nTax Rate: $#{mget(mem, :taxamt).mon} per message\nInvestments: #{mget(mem, :invest).to_s}\nInvestment Cost: $#{mget(mem, :invcost).mon}\nTimes Lobbied: #{mget(mem, :lbcount)}"
    end
    event.message.mentions.each do |mem|
      s = ""
      mem = mem.on(event.channel.server)
      if mget(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
         s = "$" + mget(mem, :tax).mon
      else
         s = "Paid"
      end
      n = ""
      if mem.nick
        n = mem.nick
      else
        n = mem.username
      end
      conc = n + "'s Stats\n$$\nTax: #{s}\nBalance: $#{mget(mem, :bal).mon}\nHourly Reward: $#{mget(mem, :daily).mon}\nTax Rate: $#{mget(mem, :taxamt).mon} per message\nInvestments: #{mget(mem, :invest).to_s}\nInvestment Cost: $#{mget(mem, :invcost).mon}\nTimes Lobbied: #{mget(mem, :lbcount)}"
    end
    if args.include? "noborder"
      event.respond "```" + conc + "```"
    else
      event.respond "```" + conc.pad + "```"
    end
  end
  
  def Command.reward(event)
    mem = event.author
    unless mget(mem, :day) == todays
      mset(mem, :bal, mget(mem, :daily).to_i + mget(mem, :bal).to_i)
      mset(mem, :day, todays)
      event.respond "**Collected $#{sprintf "%.2f", mget(mem, :daily).to_f * 0.01} from the bank.**"
    else
      event.respond "You already collected your reward!"
    end
  end
  
  def Command.lobby(event, type)
    mem = event.author
    unless mget(mem, :lbday) == Date.today.to_s
      if ["taxes", "investments", "rates"].include? type
        mset(mem, :lbday, Date.today.to_s)
        mset(mem, :lbcount, mget(mem, :lbcount).to_i + 1)
        chance = 4
        if Date.today.sunday? or Date.today.saturday?
          chance = 9
        end
        if rand(chance) == 1
          event.respond "***YOU WERE CAUGHT IN THE PROCESS OF LOBBYING. YOU WERE SUED BY THE STATE.***"
          mset(mem, :tax, mget(mem, :lbcount).to_i*mget(mem, :invcost).to_i/2 + mget(mem, :tax).to_i)
        else
          if type == "rates"
            event.respond "**You successfully lobbied the tax code!**"
            unless mget(mem, :taxamt).to_i < 4
              mset(mem, :taxamt, mget(mem, :taxamt).to_i - rand(3))
            end
          elsif type == "investments"
            event.respond "**You successfully lobbied the stock market!**"
            mset(mem, :invcost, mget(mem, :invcost).to_i - (mget(mem, :invcost).to_i / 3))
          elsif type == "taxes"
            event.respond "**You successfully lobbied your local tax collecter!**"
            mset(mem, :tax, mget(mem, :tax).to_i / 2) 
          end
        end
      else
        event.respond "You can only lobby three agencies: investments, taxes, and rates."
        tax mem,event
      end
    else
      event.respond "You have already lobbied today!"
    end
  end
  
  def Command.help(event)
    event.channel.send_embed do |em|
      em.title = "Commands"
      em.color = 313600
      af(em, "help", "not hard to guess")
      af(em, "taxes [users]", "displays tax information")
      af(em, "balance [users]", "displays balance - aliases: bal, money")
      af(em, "info [users]", "displays everything you need to know - alias: stats")
      af(em, "pay (user) (amount)", "give someone some of your money")
      af(em, "collect", "collect your hourly wages")
      af(em, "invest", "invest money (shown in #{$prefix}info) to increase your hourly payment")
      af(em, "lobby (investments|taxes|rates)", "lobby the government to decrease one of your debts")
      af(em, "top [bal|invcount|lbcount)", "see the leaderboards")
      af(em, "freeze", "opt out of tax bot")
      af(em, "paytaxes", "p a y   y o u r   t a x e s")
      em.footer = Discordrb::Webhooks::EmbedFooter.new(text: "the irs is always watching", icon_url: $bot.profile.avatar_url)
    end
  end
  
  def Command.pay(event, ment, amt)
    mem = event.author
    amt = amt.to_s.match(/[\d\.]+/)[0].to_f.*(100).to_i
    bal = mget(mem, :bal).to_i
    if mget(mem, :payc).to_i < Time.at(Time.now-60)
      if mget(event.message.mentions[0].on(event.channel.server), :invcost).to_i*2 < amt
        if amt <= mget(mem, :bal).to_i
          if event.message.mentions.size == 1
            mem2 = event.message.mentions[0].on(event.channel.server)
            mset(mem, :bal, bal-amt)
            mset(mem2, :bal, mget(mem2, :bal).to_i + amt)
            event.respond "**Paid " + mem2.mention + " $#{sprintf "%.2f", amt.to_f * 0.01}.**"
          else
            event.respond "Mention someone to pay them!"
            tax mem,event
          end
        else
          event.respond "Not enough money!"
        end
      else
        event.respond "You are paying this user too much!"
    else
      event.respond "You can only pay someone once per minute!"
    end
  end
    
  def Command.invest(event)
    mem = event.author.on(event.channel.server)
    if mget(mem, :invcost).to_i <= mget(mem, :bal).to_i
      event.respond "*Invested $#{sprintf "%.2f", mget(mem, :invcost).to_f * 0.01} into the stock market.*"
      mset(mem, :bal, mget(mem, :bal).to_i - mget(mem, :invcost).to_i)
      diff = (rand(mget(mem, :invcost).to_i/5) - mget(mem, :invcost).to_i/20) * 2
      if diff > 0
        event.respond "**Success!** Your investments matured and you recived a $#{sprintf "%.2f", diff.to_f * 0.01} raise!"
      else
        event.respond "**Oh no!** Your investments failed and you took a $#{sprintf "%.2f", diff.to_f * -0.01} cut."
      end
      mset(mem, :invcost, mget(mem, :invcost).to_i + (mget(mem, :invcost).to_i / 5) + diff)
      mset(mem, :daily, mget(mem, :daily).to_i + diff)
      mset(mem, :invest, mget(mem, :invest).to_i + 1)
      irs = rand(2)
      if irs == 1 and diff > 0 
        event.respond "*The IRS saw your investment and decided to raise your taxes.*"
        mset(mem, :taxamt, mget(mem, :taxamt).to_i + mget(mem, :invcost).to_i / 100)
      else
        irs = 0
      end
    else
      event.respond "Not enough money!"
    end
  end
  
  def Command.paytaxes(event)
    mem = event.author
    if mget(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
      if mget(mem, :tax).to_i <= mget(mem, :bal).to_i
        if taxdays(Date.today)
          mset(mem, :bal, mget(mem, :bal).to_i - mget(mem, :tax).to_i)
          mset(mem, :tax, 0)
          mset(mem, :month, Date.today.year.to_s + "-" + Date.today.month.to_s)
          event.respond "Taxes paid for the month of " + Date.today.strftime("%B") + "."
        else
          event.respond "You may only pay your taxes on the last 5 days of the month!"
        end
      else
        event.respond "You do not have enough money to pay your taxes!"
      end
    else
      event.respond "You have already paid your taxes this month!"
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

$bot.ready do
  $bot.game= "do "+$prefix+"help | " + (ENV['HEROKU_RELEASE_VERSION'] if ENV['DEV'] != "false")
end

$bot.run 
