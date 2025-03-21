class UserNotifierMailer < ApplicationMailer
  default from: "contact@crozetbikepolo.com"

  def test_email
    mail(
      to: "elias.fatsi.24@gmail.com",
      subject: "Testing it out"
    )
  end
end
