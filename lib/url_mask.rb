class URLMask

  ## The mask URL string for this URLMask.
  attr_reader :mask

  ## Creates a new URLMask with the given mask URL string.
  def initialize(mask)
    @mask = mask
  end

  ## Returns this URLMask's mask URL string.
  def to_s
    mask
  end

  ## Returns true if this URLMask matches the given URL string, false
  ## otherwise.
  def matches?(url)
    begin
      self.class.compare_decomposed(decomposed_mask,
                                    self.class.decompose_url(url))
    rescue ArgumentError
      false
    end
  end

private

  ## Returns and memoizes this URLMask's decomposed form.
  def decomposed_mask
    @decomposed_mask ||= self.class.decompose_url(self.mask)
  end

public

  class << self

    ## Given a URL, returns a hash containing :protocol, :username, :password,
    ## :hostname, :port, :path, :query, and :fragment (all String).
    ## Returns nil if given a malformed URL.
    def decompose_url(url)
      if m = url.match(%r{
            ^

            (?: ([a-zA-Z]+) ://)?         ## m[1] is protocol

            (?: ([a-zA-Z0-9]+)            ## m[2] is username
                (?: : ([a-zA-Z0-9]*))     ## m[3] is password
                @
            )?

            ([a-zA-Z0-9\.\*\-]+?)?        ## m[4] is hostname
                                          ## match * too

            (?: : (\*|\d+))?              ## m[5] is port
                                          ## match * too

            (/ [^\?\#]*)?                 ## m[6] is path

            (?: \? ([^\#]*) )?            ## m[7] is query

            (?: \# (.*) )?                ## m[8] is fragment

            $
          }x)
        protocol = m[1] ? m[1].downcase : nil
        username = m[2]
        password = m[3]
        hostname = m[4] ? m[4].downcase : nil

        port = m[5] ? m[5].to_i : nil
        port = port.to_i if port

        path = m[6]

        query    = m[7]
        fragment = m[8]

        { :protocol => protocol,
          :username => username,
          :password => password,
          :hostname => hostname,
          :port => port,
          :path => path,
          :query => query,
          :fragment => fragment }

      else ## no match
        nil
      end
    end

    ## Compares a URL mask string with a URL string.  Returns true on
    ## positive match, false otherwise.
    def compare(mask, url)
      unless mask_parts = decompose_url(mask)
        raise ArgumentError, "Badly formed URL mask: #{mask.inspect}"
      end
      unless url_parts = decompose_url(url)
        raise ArgumentError, "Badly formed URL: #{url.inspect}"
      end
      compare_decomposed(mask_parts, url_parts)
    end


    ## Compares a decomposed URL mask with a decomposed URL string.
    ## Returns true on positive match, false otherwise.
    def compare_decomposed(mask, url)
      return false unless compare_protocols_and_ports(mask, url)
      return false unless fuzzy_match(mask[:username], url[:username])
      return false unless fuzzy_match(mask[:password], url[:password])
      return false unless fuzzy_match(mask[:query], url[:query])
      return false unless fuzzy_match(mask[:fragment], url[:fragment])
      return false unless compare_hostnames(mask[:hostname], url[:hostname])
      return false unless compare_paths(mask[:path], url[:path])
      true
    end

  private

    ## Compares protocol and port information.  Returns true on positive match.
    def compare_protocols_and_ports(mask_parts, url_parts)
      mask_protocol = mask_parts[:protocol] || 'http'
      url_protocol = url_parts[:protocol] || 'http'
      if mask_parts[:protocol]
        return false if mask_protocol != '*' && mask_protocol != url_protocol
      end

      mask_port = mask_parts[:port]
      url_port = url_parts[:port] || PORT_BY_PROTOCOL[url_protocol]
      if mask_parts[:port]
        return false if mask_port != '*' && mask_port != url_port
      end

      true
    end

    PORT_BY_PROTOCOL = {
      'http'  => 80,
      'https' => 443,
      'file'  => nil,
    }

    ## Compares two elements of a URL.  
    def fuzzy_match(mask, piece)
      return false if mask && piece && mask != piece && mask != '*'
      true
    end

    ## *.example.com => 'com', 'example', '*'
    ## example.com   => 'com', 'example'
    ## This should not match.
    def compare_hostnames(mask, host)
      compare_pieces((mask || '').split('.').reverse,
                     (host || '').split('.').reverse,
                     :ignore_depth => false)
    end

    ## /some/path/*  => '', 'some', 'path', '*'
    ## /some/path    => '', 'some', 'path'
    ## This should match.
    def compare_paths(mask, path)
      compare_pieces((mask || '*').split(%r{/}),
                     (path || '/').split(%r{/}),
                     :ignore_depth => true)
    end

    ## Compares arrays of URL or hostname pieces.
    def compare_pieces(mask, pieces, args)
      ignore_depth = args[:ignore_depth]
      return false if !ignore_depth && mask.count > pieces.count
      pieces.each_with_index do |piece, i|
        return true if piece && mask[i] == '*'
        return false if mask[i] != piece
      end
      true
    end

  end # class << self

end
