#!/usr/local/bin/ruby
## https://raw.github.com/kentaro/serf-hosts/master/event_handler.pl
## https://github.com/customink-webops/hostsfile/blob/master/libraries/entry.rb

require 'digest/sha2'
class Manipulator
  attr_accessor :entries
  attr_accessor :hostsfile_path
  def initialize(hostsfile_path='/etc/hosts')
    @hostsfile_path = hostsfile_path
    @entries = []
    collect_and_flatten(::File.readlines(hostsfile_path))
  end

  # Return a list of all IP Addresses for this hostsfile.
  #
  # @return [Array<IPAddr>]
  #   the list of IP Addresses
  def ip_addresses
    @entries.collect do |entry|
      entry.ip_address
    end.compact || []
  end

  # Add a new record to the hostsfile.
  #
  # @param [Hash] options
  #   a list of options to create the entry with
  # @option options [String] :ip_address
  #   the IP Address for this entry
  # @option options [String] :hostname
  #   the hostname for this entry
  # @option options [String, Array<String>] :aliases
  #   a alias or array of aliases for this entry
  # @option options[String] :comment
  #   an optional comment for this entry
  # @option options [Fixnum] :priority
  #   the relative priority of this entry (compared to others)
  def add(options = {})
    entry = Entry.new(
      ip_address: options[:ip_address],
      hostname:   options[:hostname],
      aliases:    options[:aliases],
      comment:    options[:comment],
      priority:   options[:priority],
    )

    @entries << entry
    remove_existing_hostnames(entry) if options[:unique]
  end

  # Update an existing entry. This method will do nothing if the entry
  # does not exist.
  #
  # @param (see #add)
  def update(options = {})
    if entry = find_entry_by_ip_address(options[:ip_address])
      entry.hostname  = options[:hostname]
      entry.aliases   = options[:aliases]
      entry.comment   = options[:comment]
      entry.priority  = options[:priority]

      remove_existing_hostnames(entry) if options[:unique]
    end
  end

  # Append content to an existing entry. This method will add a new entry
  # if one does not already exist.
  #
  # @param (see #add)
  def append(options = {})
    if entry = find_entry_by_ip_address(options[:ip_address])
      hosts          = normalize(entry.hostname, entry.aliases, options[:hostname], options[:aliases])
      entry.hostname = hosts.shift
      entry.aliases  = hosts

      unless entry.comment && options[:comment] && entry.comment.include?(options[:comment])
        entry.comment = normalize(entry.comment, options[:comment]).join(', ')
      end

      remove_existing_hostnames(entry) if options[:unique]
    else
      add(options)
    end
  end

  # Remove an entry by it's IP Address
  #
  # @param [String] ip_address
  #   the IP Address of the entry to remove
  def remove(ip_address)
    if entry = find_entry_by_ip_address(ip_address)
      @entries.delete(entry)
    end
  end

  # Save the new hostsfile to the target machine. This method will only write the
  # hostsfile if the current version has changed. In other words, it is convergent.
  def save
    entries = []
    entries << '#'
    entries << '# This file is managed by Chef, using the hostsfile cookbook.'
    entries << '# Editing this file by hand is highly discouraged!'
    entries << '#'
    entries << '# Comments containing an @ sign should not be modified or else'
    entries << '# hostsfile will be unable to guarantee relative priority in'
    entries << '# future Chef runs!'
    entries << '#'
    entries << ''
    entries += unique_entries.map(&:to_line)
    entries << ''

    contents = entries.join("\n")
    contents_sha = Digest::SHA512.hexdigest(contents)

    # Only write out the file if the contents have changed...
    if contents_sha != current_sha
      ::File.open(hostsfile_path, 'w') do |f|
        f.write(contents)
      end
    end
  end


  # Find an entry by the given IP Address.
  #
  # @param [String] ip_address
  #   the IP Address of the entry to find
  # @return [Entry, nil]
  #   the corresponding entry object, or nil if it does not exist
  def find_entry_by_ip_address(ip_address)
    @entries.find do |entry|
      !entry.ip_address.nil? && entry.ip_address == ip_address
    end
  end

  # Determine if the current hostsfile contains the given resource. This
  # is really just a proxy to {find_resource_by_ip_address} /
  #
  # @param [Chef::Resource] resource
  #
  # @return [Boolean]
  def contains?(resource)
    !!find_entry_by_ip_address(resource.ip_address)
  end

private

  # The current sha of the system hostsfile.
  #
  # @return [String]
  #   the sha of the current hostsfile
  def current_sha
    @current_sha ||= Digest::SHA512.hexdigest(File.read(hostsfile_path))
  end


  # Normalize the given list of elements into a single array with no nil
  # values and no duplicate values.
  #
  # @param [Object] things
  #
  # @return [Array]
  #   a normalized array of things
  def normalize(*things)
    things.flatten.compact.uniq
  end

  # This is a crazy way of ensuring unique objects in an array using a Hash.
  #
  # @return [Array]
  #   the sorted list of entires that are unique
  def unique_entries
    entries = Hash[*@entries.map { |entry| [entry.ip_address, entry] }.flatten].values
    entries.sort_by { |e| [-e.priority.to_i, e.hostname.to_s] }
  end



  # Takes /etc/hosts file contents and builds a flattened entries
  # array so that each IP address has only one line and multiple hostnames
  # are flattened into a list of aliases.
  #
  # @param [Array] contents
  #   Array of lines from /etc/hosts file
  def collect_and_flatten(contents)
    contents.each do |line|
      entry = Entry.parse(line)
      next if entry.nil?

      append(
        ip_address: entry.ip_address,
        hostname:   entry.hostname,
        aliases:    entry.aliases,
        comment:    entry.comment,
        priority:   !entry.calculated_priority? && entry.priority,
      )
    end
  end


  # Removes duplicate hostnames in other files ensuring they are unique
  #
  # @param [Entry] entry
  #   the entry to keep the hostname and aliases from
  #
  # @return [nil]
  def remove_existing_hostnames(entry)
    @entries.delete(entry)
    changed_hostnames = [entry.hostname, entry.aliases].flatten.uniq

    @entries = @entries.collect do |entry|
      entry.hostname = nil if changed_hostnames.include?(entry.hostname)
      entry.aliases  = entry.aliases - changed_hostnames

      if entry.hostname.nil?
        if entry.aliases.empty?
          nil
        else
          entry.hostname = entry.aliases.shift
          entry
        end
      else
        entry
      end
    end.compact

    @entries << entry

    nil
  end



end



require 'ipaddr'

# An object representation of a single line in a hostsfile.
#
# @author Seth Vargo <sethvargo@gmail.com>
class Entry
  class << self
    # Creates a new Hostsfile::Entry object by parsing a text line. The
    # `line` attribute will be in the following format:
    #
    #     1.2.3.4 hostname [alias[, alias[, alias]]] [# comment [@priority]]
    #
    # @param [String] line
    #   the line to parse
    # @return [Entry]
    #   a new entry object
    def parse(line)
      entry, comment = extract_comment(line)
      comment, priority = extract_priority(comment)
      entries = extract_entries(entry)

      # Return nil if the line is empty
      return nil if entries.nil? || entries.empty?

      return self.new(
        ip_address: entries[0],
        hostname:   entries[1],
        aliases:    entries[2..-1],
        comment:    comment,
        priority:   priority,
      )
    end

    private
      def extract_comment(line)
        return nil if presence(line).nil?
        line.split('#', 2).collect { |part| presence(part) }
      end

      def extract_priority(comment)
        return nil if comment.nil?

        if comment.include?('@')
          comment.split('@', 2).collect { |part| presence(part) }
        else
          [comment, nil]
        end
      end

      def extract_entries(entry)
        return nil if entry.nil?
        entry.split(/\s+/).collect { |entry| presence(entry) }.compact
      end

      def presence(string)
        return nil if string.nil?
        return nil if string.strip.empty?
        string.strip
      end
  end

  # @return [String]
  attr_accessor :ip_address, :hostname, :aliases, :comment, :priority

  # Creates a new entry from the given options.
  #
  # @param [Hash] options
  #   a list of options to create the entry with
  # @option options [String] :ip_address
  #   the IP Address for this entry
  # @option options [String] :hostname
  #   the hostname for this entry
  # @option options [String, Array<String>] :aliases
  #   a alias or array of aliases for this entry
  # @option options[String] :comment
  #   an optional comment for this entry
  # @option options [Fixnum] :priority
  #   the relative priority of this entry (compared to others)
  #
  # @raise [ArgumentError]
  #   if neither :ip_address nor :hostname are supplied
  def initialize(options = {})
    if options[:ip_address].nil? || options[:hostname].nil?
      raise ArgumentError, ':ip_address and :hostname are both required options'
    end

    @ip_address = IPAddr.new(options[:ip_address].to_s)
    @hostname   = options[:hostname]
    @aliases    = [options[:aliases]].flatten.compact
    @comment    = options[:comment]
    @priority   = options[:priority] || calculated_priority
  end

  # Set a the new priority for an entry.
  #
  # @param [Fixnum] new_priority
  #   the new priority to set
  def priority=(new_priority)
    @calculated_priority = false
    @priority = new_priority
  end

  # The line representation of this entry.
  #
  # @return [String]
  #   the string representation of this entry
  def to_line
    hosts = [hostname, aliases].flatten.join(' ')

    comments = "# #{comment.to_s}".strip
    comments << " @#{priority}" unless priority.nil? || @calculated_priority
    comments = comments.strip
    comments = nil if comments == '#'

    [ip_address, hosts, comments].compact.join("\t").strip
  end

  # Returns true if priority is calculated
  #
  # @return [Boolean]
  #   true if priority is calculated and false otherwise
  def calculated_priority?
    @calculated_priority
  end

  private

    # Calculates the relative priority of this entry.
    #
    # @return [Fixnum]
    #   the relative priority of this item
    def calculated_priority
      @calculated_priority = true

      return 81 if ip_address == IPAddr.new('127.0.0.1')
      return 80 if IPAddr.new('127.0.0.0/8').include?(ip_address) # local
      return 60 if ip_address.ipv4? # ipv4
      return 20 if ip_address.ipv6? # ipv6
      return 00
    end
end



hostsfile = '/etc/hosts'
event     = ENV["SERF_EVENT"]

manipulator = Manipulator.new(hostsfile)

case event
  when "member-join" then
    ARGF.each_line do |line|
      name, address, role = line.split
      manipulator.add(:ip_address => address, :hostname => name)
    end
  when "member-leave", "member-failed" then
    ARGF.each_line do |line|
      name, address, role = line.split
      manipulator.remove(address)
    end
  else
end

manipulator.save
