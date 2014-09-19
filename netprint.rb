require './base'

class NetPrint < Base
  self.url = 'https://www.printing.ne.jp/'

  def login
    s.visit NetPrint.url + 'login.html'
    s.fill_in :i, with: conf['id']
    s.fill_in :p, with: conf['password']
    s.find(:css, 'input[name="login"]').click
  end

  def register(file)
    login
    s.find(:css, 'img[name="Image22"]').click
    delay

    s.attach_file 'file1', file
    s.choose 'papersize', option: '0'
    s.choose 'color',     option: '0'
    s.choose 'number',    option: '1'
    s.find(:css, 'img[name="upload"]').click

    delay
    20.times do
      reg_id = s.find(:xpath, '//table//form/table//tr[3]//table[4]//tr[2]/td[3]').text.to_i
      return reg_id if reg_id > 0
      delay 6
    end
  end
end
