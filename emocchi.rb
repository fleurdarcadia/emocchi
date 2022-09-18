require 'fileutils'
require 'net/http'

require 'discordrb'


MACRO_SYNTAX = />([\w_-]+)</

class Emocchi
  def initialize(bot)
    @bot = DiscordBot.new
    @macro_registry = MacroRegistry.new
  end

  def provide(services)
    @bot.register_commands(services, @macro_registry)
    @bot.run
  rescue Interrupt
    @macro_registry.persist
  end
end

class DiscordBot
  def initialize(token: ENV["BOT_KEY"])
    @bot = Discordrb::Bot.new(token: token)
  end

  def register_commands(services, macro_registry)
    @bot.message do |event|
      request = services.find { |service| service.requested?(event.message.content) }
      request.perform(macro_registry, event) if request
    end
  end
  
  def run
    @bot.run
  end
end

class FileSystem
  class << self
    LOCK_DIR = File.join(".emocchi", "locks")

    def write(dir, file, data)
      FileUtils.mkdir_p(dir)
      File.open(File.join(dir, file), 'wb') do |image_file|
        image_file.write(data)
      end
    end

    def delete(dir, file)
      FileUtils.rm(File.join(dir, file))
    end

    def replace(dir, old_file, new_file)
      FileUtils.mv(File.join(dir, old_file), File.join(dir, new_file))
    end

    def read(dir, file)
      path = File.join(dir, file)
      return nil unless File.exist?(path)

      File.read(path)
    end

    def reader(dir, file)
      File.open(File.join(dir, file), "rb") { |f| yield f }
    end
  end
end

class MacroRegistry
  MACROS_FILE = "macros.json"
  IMAGES_DIRECTORY = "images"

  def initialize
    @register = load_register
  end

  def store(server, trigger, file_name)
    @register[server] = {} unless @register.key?(server)
    return if @register[server].key?(trigger)

    @register[server][trigger] = file_name

    persist
  end

  def retrieve(server, trigger)
    @register.fetch(server, {})[trigger]
  end

  def remove(server, trigger)
    return unless @register.key?(server)

    file_path = @register[server].delete(trigger)
    persist
  end

  def list_triggers(server)
    @register.fetch(server, {}).keys
  end

  def persist
    FileSystem.write(__dir__, MACROS_FILE, JSON.generate(@register))
  end
  
  private

  def load_register
    json = FileSystem.read(__dir__, MACROS_FILE)
    return {} unless json

    JSON.parse(json)
  end
end

class Service
  class NotImplemented < StandardError; end

  def requested?(message)
    raise NotImplemented, "requested? is not implemented"
  end

  def perform(bot, macro_registry, event)
    raise NotImplemented, "perform is not implemented"
  end
end

class RetrieveAnImage < Service
  def requested?(message)
    MACRO_SYNTAX.match(message)
  end

  def perform(macros, event)
    server = event.server.name
    trigger = MACRO_SYNTAX.match(event.message.content).to_a[1]
    file_name = macros.retrieve(server, trigger)

    return event.respond("I have not been taught `#{trigger}` yet, Master. :pensive:") unless file_name

    FileSystem.reader(File.join(MacroRegistry::IMAGES_DIRECTORY, server), file_name) do |file|
      event.send_file(file)
    end
  end
end

class RememberNewMacro < Service
  def requested?(message)
    message.start_with?("!reg")
  end

  def perform(macros, event)
    server = event.server.name
    trigger, image_url = event.message.content.split(" ")[1..2]
    dir = File.join(MacroRegistry::IMAGES_DIRECTORY, server)

    return event.respond("I have already been taught `#{trigger}`, Master. :worried:") if macros.retrieve(server, trigger)

    image_data = download_image(image_url)
    return event.respond("I was not able to download that image. :worried:") unless image_data

    # Need to save the file to detect its extension with the unix `file` utility.
    file_name = save_image(dir, trigger, image_data)
    return event.respond("That doesn't seem to be an image I can work with... :worried:") unless file_name

    macros.store(server, trigger, file_name)
    event.respond("I have remembered `#{trigger}` just for you, Master~! :heart:")
  end

  private

  def download_image(image_url)
    uri = URI.parse(image_url)
    response = Net::HTTP.get_response(uri)
    return unless response.code.to_i == 200

    response.body
  end

  def save_image(dir, name, image_data)
    FileSystem.write(dir, name, image_data)
    extension = detect_file_extension(File.join(dir, name))

    unless extension
      FileSystem.delete(dir, name)
      return
    end

    file_name = name.end_with?(extension) ? name : [name, extension].join(".")
    FileSystem.replace(dir, name, file_name)
    file_name
  end

  def detect_file_extension(file_path)
    supported_mime_types = {
      "image/jpeg" => "jpg",
      "image/png"  => "png",
    }

    mime_type = IO.popen(["file", "--brief", "--mime-type", file_path], &:read).chomp

    supported_mime_types[mime_type]
  end
end

class ForgetAMacro < Service
  def requested?(message)
    message.start_with?("!del")
  end

  def perform(macros, event)
    server = event.server.name
    trigger = event.message.content.split(" ")[1]
    file_name = macros.retrieve(server, trigger)
    return event.respond("I have not been taught `#{trigger}` yet. :confused:") unless file_name
    
    FileSystem.delete(File.join(MacroRegistry::IMAGES_DIRECTORY, server), file_name)
    macros.remove(event.server.name, trigger)

    event.respond("As you command, Master. I forgot `#{trigger}` for you. :slight_smile:")
  end
end

class ReciteOurMacros < Service
  def requested?(message)
    message == "!list"
  end

  def perform(macros, event)
    available_triggers = format(macros.list_triggers(event.server.name))

    return event.respond("My apologies. I have not remembered any images yet. :pensive:") if available_triggers.empty?

    event.respond("Here is what I have been taught so far, Master:\n#{available_triggers}")
  end

  private

  def format(keys)
    keys.map { |key| "`#{key}`" }.each_slice(3).map { |group| group.join(", ") }.join("\n")
  end
end

def main
  maid = Emocchi.new(DiscordBot.new)
  services = [
    RetrieveAnImage.new,
    RememberNewMacro.new,
    ForgetAMacro.new,
    ReciteOurMacros.new,
  ]

  maid.provide(services)
end

main
