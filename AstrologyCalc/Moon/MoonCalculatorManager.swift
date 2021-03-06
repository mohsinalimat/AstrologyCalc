//
//  MoonCalculatorManager.swift
//  AstrologyCalc
//
//  Created by Emil Karimov on 06/03/2019.
//  Copyright © 2019 Emil Karimov. All rights reserved.
//

import UIKit
import CoreLocation

//Тут все расчеты
public class MoonCalculatorManager {

    //Геопозиция
    private var location: CLLocation

    //Вызвать этот коснтруктор
    public init(location: CLLocation) {
        self.location = location
    }

    //Получить необходимую инфу
    public func getInfo(date: Date) -> AstrologyModel {
        let phase = self.getMoonPhase(date: date)
        let trajectory = self.getMoonTrajectory(date: date)
        let moonModels = self.getMoonModels(date: date)
        let astrologyModel = AstrologyModel(date: date, location: self.location, trajectory: trajectory, phase: phase, moonModels: moonModels)
        return astrologyModel
    }
}

extension MoonCalculatorManager {

    //Получить модели лунного дня для текущего человеческого дня
    private func getMoonModels(date: Date) -> [MoonModel] {
        let startDate = self.startOfDate(date)
        let endDate = self.endOfDate(date) ?? Date()

        let ages = self.getMoonAges(date: date)
        let moonRise = self.getMoonRise(date: startDate).date
        let moonSet = self.getMoonSet(date: endDate).date
        let zodiacSignStart = self.getMoonZodicaSign(date: startDate)
        let zodiacSignEnd = self.getMoonZodicaSign(date: endDate)

        if ages.count < 1 {
            return []
        } else if ages.count == 1 {
            let model = MoonModel(age: ages[0], zodiacSign: zodiacSignStart, moonRise: nil, moonSet: nil)
            return [model]
        } else if ages.count == 2 {
            let model1 = MoonModel(age: ages[0], zodiacSign: zodiacSignStart, moonRise: nil, moonSet: moonRise)
            let model2 = MoonModel(age: ages[1], zodiacSign: zodiacSignEnd, moonRise: moonRise, moonSet: nil)
            return [model1, model2]
        } else if ages.count == 3 {
            let middleZodiacSign = zodiacSignStart == zodiacSignEnd ? zodiacSignStart : zodiacSignEnd
            let model1 = MoonModel(age: ages[0], zodiacSign: zodiacSignStart, moonRise: nil, moonSet: moonRise)
            let model2 = MoonModel(age: ages[1], zodiacSign: middleZodiacSign, moonRise: moonRise, moonSet: moonSet)
            let model3 = MoonModel(age: ages[2], zodiacSign: zodiacSignEnd, moonRise: moonSet, moonSet: nil)
            return [model1, model2, model3]
        } else {
            return []
        }
    }

    //Получить восход луны
    private func getMoonRise(date: Date) -> (date: Date?, error: Error?) {
        return self.getMoonRiseOrSet(date: date, isRise: true)
    }

    //Получить заход луны
    private func getMoonSet(date: Date) -> (date: Date?, error: Error?) {
        return self.getMoonRiseOrSet(date: date, isRise: false)
    }

    //Получить массив лунных дней в текущем Человеческом дне
    private func getMoonAges(date: Date) -> [Int] {
        let startDate = self.startOfDate(date)
        let endDate = startDate.addingTimeInterval(TimeInterval(exactly: (24 * 60 * 60)) ?? 0)

        var ageStart = self.getMoonAge(date: startDate)
        var ageEnd = self.getMoonAge(date: endDate)

        let nextStartInt = Int(ageStart) + 1
        if (Double(nextStartInt) - ageStart) < 0.2 {
            ageStart = Double(nextStartInt)
        }

        let nextEndInt = Int(ageEnd) + 1
        if (Double(nextEndInt) - ageEnd) < 0.2 {
            ageEnd = Double(nextEndInt)
        }

        let ageStartInt = Int(ageStart)
        let ageEndInt = Int(ageEnd)

        if ageStartInt == ageEndInt {
            return [ageStartInt]
        } else {
            return self.getInt(from: ageStartInt, to: ageEndInt, module: 30)
        }
    }

    //Получить восход/заход луны для лунного дня
    private func getMoonRiseOrSet(date: Date, isRise: Bool) -> (date: Date?, error: Error?) {
        let (y, month, d, h, m, s, lat, lon) = self.getCurrentData(date: date)

        do {
            let moonCalculator: SunMoonCalculator = try SunMoonCalculator(year: y, month: month, day: d, h: h, m: m, s: s, obsLon: lon, obsLat: lat)
            moonCalculator.calcSunAndMoon()
            var moonDateInt: [Int]
            if isRise {
                moonDateInt = try SunMoonCalculator.getDate(moonCalculator.moonRise)
            } else {
                moonDateInt = try SunMoonCalculator.getDate(moonCalculator.moonSet)
            }

            let moonDate = self.getDateFromComponents(moonDateInt)
            return (moonDate, nil)
        } catch let error {
            return (nil, error)
        }
    }

    //Получить знак зодиака для луны
    private func getMoonZodicaSign(date: Date) -> MoonZodiacSign {
        var longitude: Double = 0.0
        var zodiac: MoonZodiacSign

        var yy: Double = 0.0
        var mm: Double = 0.0
        var k1: Double = 0.0
        var k2: Double = 0.0
        var k3: Double = 0.0
        var jd: Double = 0.0
        var ip: Double = 0.0
        var dp: Double = 0.0
        var rp: Double = 0.0

        let year: Double = Double(Calendar.current.component(.year, from: date))
        let month: Double = Double(Calendar.current.component(.month, from: date))
        let day: Double = Double(Calendar.current.component(.day, from: date))

        yy = year - floor((12 - month) / 10)
        mm = month + 9.0
        if (mm >= 12) {
            mm = mm - 12
        }

        k1 = floor(365.25 * (yy + 4712))
        k2 = floor(30.6 * mm + 0.5)
        k3 = floor(floor((yy / 100) + 49) * 0.75) - 38

        jd = k1 + k2 + day + 59
        if (jd > 2299160) {
            jd = jd - k3
        }

        ip = normalize((jd - 2451550.1) / 29.530588853)

        ip = ip * 2 * .pi

        dp = 2 * .pi * normalize((jd - 2451562.2) / 27.55454988)

        rp = normalize((jd - 2451555.8) / 27.321582241)
        longitude = 360 * rp + 6.3 * sin(dp) + 1.3 * sin(2 * ip - dp) + 0.7 * sin(2 * ip)

        if (longitude < 33.18) {
            zodiac = .aries
        } else if (longitude < 51.16) {
            zodiac = .cancer
        } else if (longitude < 93.44) {
            zodiac = .gemini
        } else if (longitude < 119.48) {
            zodiac = .cancer
        } else if (longitude < 135.30) {
            zodiac = .leo
        } else if (longitude < 173.34) {
            zodiac = .virgo
        } else if (longitude < 224.17) {
            zodiac = .libra
        } else if (longitude < 242.57) {
            zodiac = .scorpio
        } else if (longitude < 271.26) {
            zodiac = .sagittarius
        } else if (longitude < 302.49) {
            zodiac = .capricorn
        } else if (longitude < 311.72) {
            zodiac = .aquarius
        } else if (longitude < 348.58) {
            zodiac = .pisces
        } else {
            zodiac = .aries
        }

        return zodiac
    }

    //Получить фазу луны
    private func getMoonPhase(date: Date) -> MoonPhase {
        var age: Double = 0.0
        var phase: MoonPhase

        var yy: Double = 0.0
        var mm: Double = 0.0
        var k1: Double = 0.0
        var k2: Double = 0.0
        var k3: Double = 0.0
        var jd: Double = 0.0
        var ip: Double = 0.0

        let year: Double = Double(Calendar.current.component(.year, from: date))
        let month: Double = Double(Calendar.current.component(.month, from: date))
        let day: Double = Double(Calendar.current.component(.day, from: date))

        yy = year - floor((12 - month) / 10)
        mm = month + 9.0
        if (mm >= 12) {
            mm = mm - 12
        }

        k1 = floor(365.25 * (yy + 4712))
        k2 = floor(30.6 * mm + 0.5)
        k3 = floor(floor((yy / 100) + 49) * 0.75) - 38

        jd = k1 + k2 + day + 59
        if (jd > 2299160) {
            jd = jd - k3
        }

        ip = normalize((jd - 2451550.1) / 29.530588853)
        age = ip * 29.53

        if (age < 1.84566) {
            phase = .newMoon
        } else if (age < 5.53699) {
            phase = .waxingCrescent
        } else if (age < 9.22831) {
            phase = .firstQuarter
        } else if (age < 12.91963) {
            phase = .waxingGibbous
        } else if (age < 16.61096) {
            phase = .fullMoon
        } else if (age < 20.30228) {
            phase = .waningGibbous
        } else if (age < 23.99361) {
            phase = .lastQuarter
        } else if (age < 27.68493) {
            phase = .waningCrescent
        } else {
            phase = .newMoon
        }

        return phase
    }

    //Получить лунный день
    private func getMoonAge(date: Date) -> Double {
        var age: Double = 0.0

        var yy: Double = 0.0
        var mm: Double = 0.0
        var k1: Double = 0.0
        var k2: Double = 0.0
        var k3: Double = 0.0
        var jd: Double = 0.0
        var ip: Double = 0.0

        let year: Double = Double(Calendar.current.component(.year, from: date))
        let month: Double = Double(Calendar.current.component(.month, from: date))
        let day: Double = Double(Calendar.current.component(.day, from: date))

        yy = year - floor((12 - month) / 10)
        mm = month + 9.0
        if (mm >= 12) {
            mm = mm - 12
        }

        k1 = floor(365.25 * (yy + 4712))
        k2 = floor(30.6 * mm + 0.5)
        k3 = floor(floor((yy / 100) + 49) * 0.75) - 38

        jd = k1 + k2 + day + 59
        if (jd > 2299160) {
            jd = jd - k3
        }

        ip = normalize((jd - 2451550.1) / 29.530588853)
        age = ip * 29.0//53

        return age
    }

    //Получить знак зодиака для дуны, траекторию луны, фазу луны
    private func getMoonTrajectory(date: Date) -> MoonTrajectory {
        var age: Double = 0.0
        var trajectory: MoonTrajectory

        var yy: Double = 0.0
        var mm: Double = 0.0
        var k1: Double = 0.0
        var k2: Double = 0.0
        var k3: Double = 0.0
        var jd: Double = 0.0
        var ip: Double = 0.0

        let year: Double = Double(Calendar.current.component(.year, from: date))
        let month: Double = Double(Calendar.current.component(.month, from: date))
        let day: Double = Double(Calendar.current.component(.day, from: date))

        yy = year - floor((12 - month) / 10)
        mm = month + 9.0
        if (mm >= 12) {
            mm = mm - 12
        }

        k1 = floor(365.25 * (yy + 4712))
        k2 = floor(30.6 * mm + 0.5)
        k3 = floor(floor((yy / 100) + 49) * 0.75) - 38

        jd = k1 + k2 + day + 59
        if (jd > 2299160) {
            jd = jd - k3
        }

        ip = normalize((jd - 2451550.1) / 29.530588853)
        age = ip * 29.53

        if (age < 1.84566) {
            trajectory = .ascendent
        } else if (age < 5.53699) {
            trajectory = .ascendent
        } else if (age < 9.22831) {
            trajectory = .ascendent
        } else if (age < 12.91963) {
            trajectory = .ascendent
        } else if (age < 16.61096) {
            trajectory = .descendent
        } else if (age < 20.30228) {
            trajectory = .descendent
        } else if (age < 23.99361) {
            trajectory = .descendent
        } else if (age < 27.68493) {
            trajectory = .descendent
        } else {
            trajectory = .ascendent
        }

        return trajectory
    }

    //Получить дату из кмпонент дня -- например [1970, 1, 1, 12, 24, 33] -> 01.01.1970 12:24:33
    private func getDateFromComponents(_ components: [Int]) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(abbreviation: "UTC") {
            calendar.timeZone = timeZone
        }

        var dateComponents = DateComponents()
        dateComponents.year = components[0]
        dateComponents.month = components[1]
        dateComponents.day = components[2]
        dateComponents.hour = components[3]
        dateComponents.minute = components[4]
        dateComponents.second = components[5]

        let date = calendar.date(from: dateComponents)

        return date
    }

    //Получить дату дату и геопозицию ввиде -> [1970, 1, 1, 12, 24, 33, широта, долгота]
    private func getCurrentData(date: Date) -> (y: Int, month: Int, d: Int, h: Int, m: Int, s: Int, lat: Double, lon: Double) {
        let (y, month, d, h, m, s) = self.getDateComponents(from: date)
        let lat = self.location.coordinate.latitude * SunMoonCalculator.DEG_TO_RAD
        let lon = self.location.coordinate.longitude * SunMoonCalculator.DEG_TO_RAD
        return (y, month, d, h, m, s, lat, lon)
    }

    //Получить массив чисел между числами N и M (кроме 0), если M меньше N, то к M прибавляется модуль -- например, получить числа между 28 и 2 по модулю 30, будет 28, 29, 1, 2
    private func getInt(from: Int, to: Int, module: Int) -> [Int] {
        var toValue = to
        if toValue == 0 {
            toValue = module - 1
        }
        var fromValue = from
        if fromValue == 0 {
            fromValue = module - 1
        }

        if fromValue == toValue {
            return [from]
        } else {
            var array = [Int]()
            var next = fromValue
            array.append(next)

            while next != toValue {
                next += 1
                if next > module {
                    next = 1
                }
                array.append(next)
            }

            return array
        }
    }

    //Получить компоненты дня -- например 01.01.1970 12:24:33 -> [1970, 1, 1, 12, 24, 33]
    private func getDateComponents(from date: Date) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)

        return (year, month, day, hour, minute, second)
    }

    //Получить начало дня -- например 01.01.1970 23:59:59
    private func startOfDate(_ date: Date) -> Date {
        let startDate = Calendar.current.startOfDay(for: date)
        return startDate
    }

    //Получить конец дня -- например 01.01.1970 00:00:00
    private func endOfDate(_ date: Date) -> Date? {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        let endDate = Calendar.current.date(byAdding: components, to: self.startOfDate(date))
        return endDate
    }

    //нормализовать число, т.е. число от 0 до 1
    private func normalize(_ value: Double) -> Double {
        var v = value - floor(value)
        if (v < 0) {
            v = v + 1
        }
        return v
    }
}
